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
    Set(dst~: Reg, val~: UInt16)
    Mem(dst~: Reg, addr~: Reg, load~: Bool, offset~: UInt16)
    Alu(dst~: Reg, src1~: Reg, src2~: Reg, op~: AluOp)
    Jmp(dst~: LabelId, cond~: LIRCond)
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
                LIR::Jmp(dst=label, cond~) => {
                    jump_info_by_set_index.push({
                        label,
                        cond,
                        // record where to patch (index of the Set instruction)
                        index: without_labels.length(),
                        offset,
                    })

                    // emit placeholder SET and placeholder ALU (op fixed later)
                    without_labels.push(LIR::Set(dst=TMP, val=0))
                    without_labels.push(LIR::Alu(
                        dst=PC,
                        src1=PC,
                        src2=TMP,
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

fn lower_lir_to_inst(lir: LIR) -> InstOrDirective raise InstLoweringError {
    match lir {
        Ctl(op~) => Inst(Ctl(op~))
        Set(dst~, val~) => Inst(Set(dst~, val~))
        Mem(offset~, ..) if offset > 0x7f => raise OffsetTooLarge(offset)
        Mem(dst~, addr~, load~, offset~) => Inst(Mem(dst~, addr~, load~, offset~))
        Alu(dst~, src1~, src2~, op~) => Inst(Alu(dst~, src1~, src2~, op~))
        Directive(dir) => Directive(dir)
        Jmp(..) => raise UnexpectedJmp
        Label(_) => raise UnexpectedLabel
    }
}

pub struct LowerIROutput {
    without_labels: Array[LIR]
    insts: Array[InstOrDirective]
}

pub fn lower_pseudo_to_lir(pseudo: Array[PseudoInst[Reg]], ctx~: &LabelContext) -> Array[LIR] raise InstLoweringError {
    match (try? lower_many(pseudo, ctx~)) {
        Err(e) => raise Pseudo(e)
        Ok(lir) => lir
    }
}

pub fn lower_lir_to_insts(lir: Array[LIR]) -> LowerIROutput raise InstLoweringError {
    let without_labels = replace_labels(lir)
    let insts = without_labels.map(lower_lir_to_inst)

    {
        without_labels,
        insts,
    }
}
