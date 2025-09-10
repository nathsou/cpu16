// Lower Intermediate Representation
// Raw instructions with labels

pub(all) struct LabelId(UInt) derive (Eq, Hash)

pub impl Show for LabelId with output(self, logger) {
    logger.write_string("L" + self.inner().to_string())
}

pub(all) enum JumpCond {
    Equ; Neq; Lss; Leq; Gtr; Geq
} derive (Show)

pub fn JumpCond::negate(self: JumpCond) -> JumpCond {
    match self {
        Equ => Neq
        Neq => Equ
        Lss => Geq
        Leq => Gtr
        Gtr => Leq
        Geq => Lss
    }
}

pub(all) enum Loc {
    Unit
    Reg(Reg)
    Label(LabelId)
    Mem(offset~: Int) // spilled variable
} derive (Show, Eq)

pub fn Loc::unit() -> Loc {
    Reg(Z)
}

pub enum LIRCond {
    Always; IfZero; IfNotZero; IfCarry; IfNotCarry
} derive (Show)

pub fn LIRCond::from(cond: UInt) -> LIRCond {
    match cond {
        1 => IfZero
        2 => IfNotZero
        3 => IfCarry
        4 => IfNotCarry
        _ => Always
    }
}

pub(all) enum LIR {
    Ctl(op~: ControlOp)
    Set(dst~: Loc, val~: UInt16)
    Mem(dst~: Loc, addr~: Loc, load~: Bool, offset~: UInt16)
    Alu(dst~: Loc, src1~: Loc, src2~: Loc, op~: AluOp)
    Jmp(dst~: Loc, cond~: LIRCond)
    Label(LabelId)
    Directive(Directive)
} derive (Show)

priv struct JumpFixupInfo {
    index: Int
    offset: Int
    label: LabelId
    cond: LIRCond
}

pub fn replace_labels(insts: Array[LIR]) -> Array[LIR] raise InstLoweringError {
    let without_labels: Array[LIR] = []
    let label_offsets: Map[LabelId, Int] = {}
    let jump_info_by_set_index: Array[JumpFixupInfo] = []

    // Execution index increments only for non-label instructions and equals physical index
    {
        let mut offset = 0

        for inst in insts {
            match inst {
                LIR::Jmp(dst=Loc::Label(label), cond~) => {
                    jump_info_by_set_index.push({
                        label,
                        cond,
                        // record where to patch (index of the Set instruction)
                        index: without_labels.length(),
                        offset,
                    })

                    // emit placeholder SET and placeholder ALU (op fixed later)
                    without_labels.push(LIR::Set(dst=Reg(TMP), val=0))
                    without_labels.push(LIR::Alu(
                        dst=Loc::Reg(Reg::PC),
                        src1=Loc::Reg(Reg::PC),
                        src2=Reg(TMP),
                        op=AluOp::Add, // placeholder; fixed in second pass
                    ))

                    offset += 2 // Set + Alu
                }
                LIR::Label(label) => {
                    // label points to the next non-label instruction
                    label_offsets[label] = offset
                    // do not emit label into final stream
                }
                LIR::Directive(directive) => {
                    match directive {
                        Origin(addr~) => {
                            offset = addr.to_int()
                        }
                    }

                    without_labels.push(inst)
                }
                _ => {
                    without_labels.push(inst)
                    offset += 1
                }
            }
        }
    }

    // Second pass: fix jump immediates and ALU ops
    for info in jump_info_by_set_index {
        let { label, cond, index: set_index, offset: set_offset } = info
        let target_offset = match label_offsets.get(label) {
            Some(pos) => pos
            None => raise MissingLabel(label)
        }

        // ALU executes right after SET
        let alu_offset = set_offset + 1
        let delta = target_offset - alu_offset
        let is_forward = delta >= 0
        let abs_delta = if is_forward { delta } else { -delta }

        // Range check against Inst::Set 11-bit immediate (0..0x7ff)
        if abs_delta > 0x7FF {
            // TODO: support long jumps
            raise JumpOutOfBounds
        }

        // Patch SET immediate
        match without_labels[set_index] {
            LIR::Set(dst~, val=_) => {
                without_labels[set_index] = LIR::Set(dst~, val=abs_delta.to_uint16())
            }
            _ => raise JumpFixupFailed
        }

        // Patch ALU op based on direction and condition
        let alu_index = set_index + 1
        match without_labels[alu_index] {
            LIR::Alu(dst~, src1~, src2~, op=_) => {
                let new_op: AluOp = match cond {
                    Always => if is_forward { Add } else { Sub }
                    IfZero => if is_forward { AddIfZero } else { SubIfZero }
                    IfNotZero => if is_forward { AddIfNotZero } else { SubIfNotZero }
                    IfCarry => if is_forward { AddIfCarry } else { SubIfCarry }
                    IfNotCarry => if is_forward { AddIfNotCarry } else { SubIfNotCarry }
                }

                without_labels[alu_index] = LIR::Alu(dst~, src1~, src2~, op=new_op)
            }
            _ => panic_msg("unexpected instruction during jump ALU fixup")
        }
    }

    without_labels
}

suberror InstLoweringError {
    UnexpectedJmp
    UnexpectedLabel
    InvalidLoc(Loc)
    JumpOutOfBounds
    MissingLabel(LabelId)
    Pseudo(PseudoLoweringError)
    NonRegLoc
    OffsetTooLarge(UInt16)
    JumpFixupFailed
} derive (Show)

pub fn spill(insts: Array[LIR]) -> Array[LIR] raise InstLoweringError {
    let spilled: Array[LIR] = Array::new(capacity=insts.length())

    fn get_reg(loc: Loc) -> Reg raise InstLoweringError {
        match loc {
            Loc::Reg(reg) => reg
            Loc::Mem(offset~) => {
                spilled.push(Mem(dst=Reg(TMP), addr=Reg(Z), load=true, offset=offset.to_uint16()))
                Reg::TMP
            }
            _ => raise InstLoweringError::InvalidLoc(loc)
        }
    }

    fn store(loc: Loc, exec: (Reg) -> Unit) -> Unit raise InstLoweringError {
        match loc {
            Loc::Reg(reg) => exec(reg)
            Loc::Mem(offset~) => {
                exec(Reg::TMP)
                // TODO: Store spilled variables in the current stack frame
                // for now, store TMP into the first 127 bytes of RAM
                spilled.push(Mem(dst=Reg(TMP), addr=Reg(Z), load=false, offset=offset.to_uint16()))
            }
            _ => raise InstLoweringError::InvalidLoc(loc)
        }
    }

    for inst in insts {
        match inst {
            LIR::Ctl(op~) => {
                spilled.push(Ctl(op~))
            }
            LIR::Set(dst~, val~) => {
                store(dst, dst_reg => {
                    spilled.push(Set(dst=Reg(dst_reg), val~))
                })
            }
            LIR::Mem(dst~, addr~, load~, offset~) => {
                let addr_reg = get_reg(addr)

                if load {
                    store(dst, dst_reg => {
                        spilled.push(Mem(dst=Reg(dst_reg), addr=Reg(addr_reg), load=true, offset~))
                    })
                } else {
                    let src_reg = get_reg(dst)
                    spilled.push(Mem(dst=Reg(src_reg), addr=Reg(addr_reg), load=false, offset~))
                }
            }
            LIR::Alu(dst~, src1~, src2~, op~) => {
                let src1_reg = get_reg(src1)

                if src1 is Mem(_) && src2 is Mem(_) {
                    match dst {
                        Mem(_) => {
                            // if src1, src2 and dst are all memory locations, then we're out of luck
                            // since we only have one temporary register (TMP)
                            panic_msg("cannot handle ALU operation with all three operands in memory: \{inst}")
                        }
                        Reg(dst_reg) => {
                            // if both arguments are memory locations
                            // then the second load from memory will overwrite the first one (in the TMP register)
                            // so we move src1 to dst first
                            // and compute dst = dst + src2
                            spilled.push(Alu(dst=Reg(dst_reg), src1=Reg(src1_reg), src2=Reg(Z), op=Add))
                            let src2_reg = get_reg(src2)

                            store(dst, dst_reg => {
                                spilled.push(Alu(dst=Reg(dst_reg), src1=Reg(dst_reg), src2=Reg(src2_reg), op~))
                            })
                        }
                        Label(_) | Unit => panic_msg("invalid dst location")
                    }
                } else {
                    let src2_reg = get_reg(src2)

                    store(dst, dst_reg => {
                        spilled.push(Alu(dst=Reg(dst_reg), src1=Reg(src1_reg), src2=Reg(src2_reg), op~))
                    })
                }
            }
            LIR::Jmp(dst~, cond~) => {
                spilled.push(Jmp(dst~, cond~))
            }
            LIR::Label(label) => {
                spilled.push(Label(label))
            }
            LIR::Directive(directive) => {
                spilled.push(Directive(directive))
            }
        }
    }

    spilled
}

fn lower_lir_to_inst(lir: LIR) -> InstOrDirective raise InstLoweringError {
    match lir {
        Ctl(op~) => Inst(Ctl(op~))
        Set(dst=Reg(dst), val~) => Inst(Set(dst~, val~))
        Mem(offset~, ..) if offset > 0x7f => raise OffsetTooLarge(offset)
        Mem(dst=Reg(dst), addr=Reg(addr), load~, offset~) => Inst(Mem(dst~, addr~, load~, offset~))
        Alu(dst=Reg(dst), src1=Reg(src1), src2=Reg(src2), op~) => Inst(Alu(dst~, src1~, src2~, op~))
        Directive(dir) => Directive(dir)
        _ => raise NonRegLoc 
    }
}

pub struct LowerIROutput {
    without_labels: Array[LIR]
    insts: Array[InstOrDirective]
}

pub fn lower_pseudo_to_lir(pseudo: Array[PseudoInst]) -> Array[LIR] raise InstLoweringError {
    match (try? lower_many(pseudo)) {
        Err(e) => raise Pseudo(e)
        Ok(lir) => lir
    }
}

pub fn lower_lir_to_insts(lir: Array[LIR]) -> LowerIROutput raise InstLoweringError {
    let spilled = spill(lir)
    let without_labels = replace_labels(spilled)
    let insts = without_labels.map(lower_lir_to_inst)

    {
        without_labels,
        insts,
    }
}
