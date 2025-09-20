
pub struct PseudoBuilder[T] {
    functions: Map[String, PseudoFunc[T]]
    insts: Array[@asm.PseudoInst[T]]
}

const TEMP_VAR_ID: UInt = 0U

pub fn[T] PseudoBuilder::new() -> PseudoBuilder[T] {
    {
        functions: {},
        insts: [],
    }
}

pub fn[T] PseudoBuilder::emit(self: PseudoBuilder[T], inst: @asm.PseudoInst[T]) -> Unit {
    self.insts.push(inst)
}

suberror IRBuilderError String derive (Show)

pub(all) struct PseudoFunc[T] {
    name: String
    label: @asm.LabelId
    body: Array[@asm.PseudoInst[T]]
    return_type: Type
    mut spilled_locals: UInt16
}

priv struct MemAlloc {
    offsets: Map[@asm.VarId, UInt16]
    base_offset: UInt16
}

fn MemAlloc::new(base_offset: UInt16) -> MemAlloc {
    { offsets: {}, base_offset }
}

fn MemAlloc::assign(self: MemAlloc, var_id: @asm.VarId) -> UInt16 {
    match self.offsets.get(var_id) {
        Some(offset) => offset
        None => {
            let offset = self.base_offset + self.offsets.size().to_uint16()
            self.offsets[var_id] = offset
            offset
        }
    }
}

pub fn PseudoBuilder::lower(self: PseudoBuilder[@asm.Reg], func: TACFunc2) -> PseudoFunc[@asm.Reg] raise IRBuilderError {
    // return address
    let params_offset: UInt16 = 1
    let spilled_offset: UInt16 = params_offset + func.parameters.length().to_uint16()
    let mem = MemAlloc::new(spilled_offset)

    let body: Array[@asm.PseudoInst[@asm.Reg]] = Array::new(capacity=func.body.length())

    fn store(var_id: @asm.VarId, reg: @asm.Reg) -> Unit {
        let offset = mem.assign(var_id)
        body.push(Store(dst=SP, src=reg, offset~))
    }

    let mut next_reg = @asm.Reg::R1

    fn read_reg_offset(var_id: @asm.VarId, base_offset: UInt16) -> @asm.Reg {
        next_reg = match next_reg {
            R1 => R2
            R2 => R3
            R3 => R4
            _ => R1
        }

        let offset = base_offset + mem.assign(var_id)
        body.push(Load(dst=next_reg, addr=SP, offset~))

        next_reg
    }

    fn read_reg(var_id: @asm.VarId) -> @asm.Reg {
        read_reg_offset(var_id, 0)
    }

    fn write_reg() -> @asm.Reg {
        next_reg = match next_reg {
            R1 => R2
            R2 => R3
            R3 => R4
            _ => R1
        }

        next_reg
    }

    for item in func.body {
        match item {
            TAC::Assign(target~, val~) => {
                let dst = write_reg()
                body.push(Setw(dst~, val=match val {
                    Integer(n, _) => n.to_uint16()
                    Boolean(q) => if q { 1 } else { 0 }
                }))
                store(target, dst)
            }
            TAC::Move(target~, src~) => {
                if target != src {
                    let dst = write_reg()
                    let src = read_reg(src)
                    body.push(Move(dst~, src~))
                    store(target, dst)
                }
            }
            TAC::Unary(target~, op~, arg~) => {
                let dst = write_reg()
                let src = read_reg(arg)

                match op {
                    UnaryOp::Not => {
                        body.push(Not2(dst~, src~))
                    }
                }

                store(target, dst)
            }
            TAC::Binary(target~, lhs~, op~, rhs~) => {
                let dst = write_reg()
                let src1 = read_reg(lhs)
                let src2 = read_reg(rhs)

                match op {
                    Add => body.push(Add(dst~, src1~, src2~))
                    Sub => body.push(Sub(dst~, src1~, src2~))
                    Mul => raise IRBuilderError("multiplication not implemented")
                    Div => raise IRBuilderError("division not implemented")
                    Mod => raise IRBuilderError("modulo not implemented")
                    Shl => body.push(Shl(dst~, src=src1, amt=src2))
                    Shr => body.push(Shr(dst~, src=src1, amt=src2))
                    BitwiseAnd | LogicalAnd => body.push(And(dst~, src1~, src2~))
                    BitwiseOr | LogicalOr => body.push(Or(dst~, src1~, src2~))
                    BitwiseXor => body.push(Xor(dst~, src1~, src2~))
                    Equ | Neq | Lss | Gtr | Leq | Geq => {
                        raise IRBuilderError("comparison operators not supported in binary expressions")
                    }
                }

                store(target, dst)
            }
            TAC::Store(dst~, src~, offset~) => {
                let dst_reg = read_reg(dst)
                let src = read_reg(src)
                body.push(Store(dst=dst_reg, src~, offset=offset.reinterpret_as_int().to_uint16()))
                store(dst, dst_reg)
            }
            TAC::Load(target~, addr~, offset~) => {
                let dst = write_reg()
                let addr = read_reg(addr)
                body.push(Load(dst~, addr~, offset=offset.reinterpret_as_int().to_uint16()))
                store(target, dst)
            }
            TAC::Jump(label~) => {
                body.push(Jmp(dst=label))
            }
            TAC::JumpIf(label~, cond~, lhs~, rhs~) => {
                let src1 = read_reg(lhs)
                let src2 = read_reg(rhs)

                let pseudo: @asm.PseudoInst[@asm.Reg] = match cond {
                    Equ => Jeq(dst=label, src1~, src2~)
                    Neq => Jne(dst=label, src1~, src2~)
                    Lss => Jlt(dst=label, src1~, src2~)
                    Gtr => Jgt(dst=label, src1~, src2~)
                    Geq => Jge(dst=label, src1~, src2~)
                    Leq => Jle(dst=label, src1~, src2~)
                }

                body.push(pseudo)
            }
            TAC::Label(label~) => {
                body.push(LIR(Label(label)))
            }
            TAC::Func(_) => @asm.panic_msg("nested functions not supported")
            GetLocal(target~, index~) => {
                let dst = write_reg() 
                body.push(Load(
                    dst~,
                    addr=SP,
                    offset=params_offset + index.reinterpret_as_int().to_uint16()
                ))
                
                store(target, dst) 
            }
            SetLocal(index=_, src=_) => {
                raise IRBuilderError("set_local not supported yet")
            }
            Return(value~) => {
                if value is Some(v) {
                    // replace return address with return value on the stack
                    let src = read_reg(v)
                    body.push(Load(dst=TMP, addr=SP, offset=0))
                    body.push(Store(dst=SP, src~, offset=0))
                    body.push(Move(dst=PC, src=TMP))
                } else {
                    body.push(Load(dst=PC, addr=SP, offset=0))
                }
            }
            TAC::Call(target~, name~, parameters~) => {
                if self.functions.get(name) is Some(({ label, return_type, spilled_locals, .. })) {
                    guard return_type == U16 else {
                        raise IRBuilderError("function return type not supported for '\{name}': '\{return_type}'")
                    }

                    guard name != func.name else {
                        // we need to know the size of the stack frame to support recursion
                        raise IRBuilderError("recursive function calls not supported for '\{name}'")
                    }

                    // step 1: Allocate space for return address + parameters + spilled locals
                    let params_offset: UInt16 = 1
                    let allocated_words = params_offset + parameters.length().to_uint16() + spilled_locals
                    body.push(Setw(dst=TMP, val=allocated_words))
                    body.push(Sub(dst=SP, src1=SP, src2=TMP))

                    // offset 0: return address

                    // step 2: push parameters into the new stack frame
                    for i in 0..<parameters.length() {
                        let src = read_reg_offset(parameters[i], allocated_words)
                        body.push(Store(dst=SP, src~, offset=params_offset + i.to_uint16()))
                    }

                    // step 3: call the function
                    body.push(LIR(Set(dst=TMP, val=4))) // return address is 4 instructions ahead
                    body.push(Add(dst=TMP, src1=TMP, src2=PC))
                    body.push(Store(dst=SP, src=TMP, offset=0)) // save return address
                    body.push(Jmp(dst=label)) // jump to function

                    // step 4: retrieve return value (if any) BEFORE deallocating
                    let return_reg = if return_type != Unit {
                        let dst = write_reg()
                        body.push(Load(dst~, addr=SP, offset=0))
                        Some(dst)
                    } else {
                        None
                    }

                    // step 5: deallocate space (restore SP)
                    body.push(Setw(dst=TMP, val=allocated_words))
                    body.push(Add(dst=SP, src1=SP, src2=TMP))

                    // step 6: store return value AFTER restoring SP
                    if return_reg is Some(reg) {
                        store(target, reg)
                    }
                } else {
                    match name {
                        "@show" => {
                            let r = read_reg(parameters[0])
                            body.push(LIR(Ctl(op=Show(r))))
                        }
                        _ => {
                            raise IRBuilderError("call to undeclared function '\{name}'")
                        }
                    }
                }
            }
        }
    }

    let pseudo_func: PseudoFunc[@asm.Reg] = {
        name: func.name,
        label: {
            if func.body[0] is Label(label=label_id) {
                label_id
            } else {
                raise IRBuilderError("function body must start with a label")
            }
        },
        body,
        return_type: func.return_type,
        spilled_locals: mem.offsets.size().to_uint16(),
    }

    self.functions[func.name] = pseudo_func

    pseudo_func
}

// no hardware detection of stack overflow, adjust layout of data in 0x0000..0x7FFF to avoid collisions
// depending on program needs (max recursion depth * stack frame size)
pub const STACK_TOP: UInt16 = 0x7fff

fn PseudoBuilder::with_main_fn_call(self: PseudoBuilder[@asm.Reg]) -> Array[@asm.PseudoInst[@asm.Reg]] raise IRBuilderError {
    let start: TACFunc2 = {
        name: "<start>",
        return_type: U16,
        parameters: [],
        body: [
            Label(label=@uint.max_value),
            Call(target=TEMP_VAR_ID, name="main", parameters=[]),
            Return(value=Some(TEMP_VAR_ID)),
        ],
    }

    let insts: Array[@asm.PseudoInst[@asm.Reg]] = [
        Directive(Origin(addr=@asm.PC_START_ADDR)),
        Setw(dst=SP, val=STACK_TOP),
        ..self.lower(start).body,
        Halt,
    ]

    for f in self.functions.values() {
        insts.push_iter(f.body.iter())
    }

    insts
}
