
pub struct PseudoBuilder {
    functions: Map[String, LowerFuncInfo]
    insts: Array[@asm.PseudoInst]
}

struct LowerFuncInfo {
    label_id: @asm.LabelId
    return_type: Type
}

const UNIT_VAR_ID: UInt = 0U

pub fn PseudoBuilder::new() -> PseudoBuilder {
    {
        functions: {},
        insts: [],
    }
}

pub fn PseudoBuilder::emit(self: PseudoBuilder, inst: @asm.PseudoInst) -> Unit {
    self.insts.push(inst)
}

suberror IRBuilderError String derive (Show)

const SAVED_REGS_COUNT: UInt16 = 4

pub fn PseudoBuilder::lower_tac(self: PseudoBuilder, item: TAC3, env: Env[VarId, VarId]) -> @asm.Loc raise IRBuilderError {
    match item {
        TAC::Assign(target~, val~) => {
            self.emit(Setw(dst=target, val=match val {
                Integer(n, _) => n.to_uint16()
                Boolean(q) => if q { 1 } else { 0 }
            }))

            target
        }
        TAC::Move(target~, src~) => {
            if target != src {
                self.emit(Move(dst=target, src~))
            }

            target
        }
        TAC::Unary(target~, op~, arg~) => {
            match op {
                UnaryOp::Not => {
                    self.emit(Not2(dst=target, src=arg))
                }
            }

            target
        }
        TAC::Binary(target~, lhs~, op~, rhs~) => {
            match op {
                Add => self.emit(Add(dst=target, src1=lhs, src2=rhs))
                Sub => self.emit(Sub(dst=target, src1=lhs, src2=rhs))
                Mul => raise IRBuilderError("multiplication not implemented")
                Div => raise IRBuilderError("division not implemented")
                Mod => raise IRBuilderError("modulo not implemented")
                Shl => self.emit(Shl(dst=target, src=lhs, amt=rhs))
                Shr => self.emit(Shr(dst=target, src=lhs, amt=rhs))
                BitwiseAnd | LogicalAnd => self.emit(And(dst=target, src1=lhs, src2=rhs))
                BitwiseOr | LogicalOr => self.emit(Or(dst=target, src1=lhs, src2=rhs))
                BitwiseXor => self.emit(Xor(dst=target, src1=lhs, src2=rhs))
                Equ | Neq | Lss | Gtr | Leq | Geq => {
                    raise IRBuilderError("comparison operators not supported in binary expressions")
                }
            }

            target
        }
        TAC::Store(dst~, src~, offset=_) => {
            self.emit(Store(dst~, src~, offset=0))
            dst
        }
        TAC::Load(target~, addr~, offset=_) => {
            self.emit(Load(dst=target, addr~, offset=0))
            target
        }
        TAC::Jump(label~) => {
            self.emit(Jmp(dst=Label(label)))
            @asm.Loc::Unit
        }
        TAC::JumpIf(label~, cond~, lhs~, rhs~) => {
            let pseudo: @asm.PseudoInst = match cond {
                Equ => Jeq(dst=Label(label), src1=lhs, src2=rhs)
                Neq => Jne(dst=Label(label), src1=lhs, src2=rhs)
                Lss => Jlt(dst=Label(label), src1=lhs, src2=rhs)
                Gtr => Jgt(dst=Label(label), src1=lhs, src2=rhs)
                Geq => Jge(dst=Label(label), src1=lhs, src2=rhs)
                Leq => Jle(dst=Label(label), src1=lhs, src2=rhs)
            }

            self.emit(pseudo)
            @asm.Loc::Unit
        }
        TAC::Label(label~) => {
            self.emit(LIR(Label(label)))
            @asm.Loc::Unit
        }
        TAC::Func(f) => {
            if f.body[0] is Label(label=label_id) {
                self.functions[f.name] = { return_type: f.return_type , label_id }
            } else {
                raise IRBuilderError("function body must start with a label")
            }
            // return address + saved registers
            let params_offset: UInt16 = 1 + SAVED_REGS_COUNT

            for inst in f.body {
                match inst {
                    GetLocal(target~, index~) => {
                        self.emit(Load(
                            dst=target,
                            addr=Reg(SP),
                            offset=params_offset + index.reinterpret_as_int().to_uint16()
                        ))
                    }
                    SetLocal(index=_, src=_) => {
                        // let source_id = self.lower_value(src, env)
                        raise IRBuilderError("set_local not supported yet")
                    }
                    Return(value~) => {
                        let is_main = f.name == "main"

                        if value is Some(v) {
                            // replace return address with return value on the stack
                            self.emit(Load(dst=Reg(TMP), addr=Reg(SP), offset=0))
                            self.emit(Store(dst=Reg(SP), src=v, offset=0))

                            if !is_main {
                                self.emit(Move(dst=Reg(PC), src=Reg(TMP)))
                            }
                        } else if !is_main {
                            // just pop the return address into PC
                            self.emit(Pop(dst=Reg(PC)))
                        }

                        if is_main {
                            // do not return from main, instead halt directly
                            self.emit(Halt)
                        }
                    }
                    _ => {
                        let _ = self.lower_tac(inst, env)
                    }
                }
            }

            @asm.Loc::Unit
        }
        TAC::Call(target~, name~, parameters~) => {
            if self.functions.get(name) is Some(({ label_id, return_type })) {
                guard return_type == U16 else {
                    raise IRBuilderError("function return type not supported for '\{name}': '\{return_type}'")
                }

                // TODO: Only save/restore registers that are used in the function body
                // step 1: Allocate space for return address + saved registers + parameters
                let params_offset: UInt16 = 1 + SAVED_REGS_COUNT
                let allocated_words = params_offset + parameters.length().to_uint16()
                self.emit(Setw(dst=Reg(TMP), val=allocated_words))
                self.emit(Sub(dst=Reg(SP), src1=Reg(SP), src2=Reg(TMP)))

                // offset 0: return address

                // step 2: save r1-r4
                self.emit(Store(dst=Reg(SP), src=Reg(R1), offset=1))
                self.emit(Store(dst=Reg(SP), src=Reg(R2), offset=2))
                self.emit(Store(dst=Reg(SP), src=Reg(R3), offset=3))
                self.emit(Store(dst=Reg(SP), src=Reg(R4), offset=4))

                // step 3: push parameters
                for i in 0..<parameters.length() {
                    self.emit(Store(dst=Reg(SP), src=parameters[i], offset=params_offset + i.to_uint16()))
                }

                // step 4: call the function 
                self.emit(LIR(Set(dst=Reg(TMP), val=4))) // return address is 4 instructions ahead
                self.emit(Add(dst=Reg(TMP), src1=Reg(TMP), src2=Reg(PC)))
                self.emit(Store(dst=Reg(SP), src=Reg(TMP), offset=0)) // save return address
                self.emit(Jmp(dst=Label(label_id))) // jump to function

                // step 5: restore r1-r4
                self.emit(Load(dst=Reg(R1), addr=Reg(SP), offset=1))
                self.emit(Load(dst=Reg(R2), addr=Reg(SP), offset=2))
                self.emit(Load(dst=Reg(R3), addr=Reg(SP), offset=3))
                self.emit(Load(dst=Reg(R4), addr=Reg(SP), offset=4))

                // step 6: retrieve return value
                if return_type != Unit {
                    self.emit(Load(dst=target, addr=Reg(SP), offset=0))
                }

                // step 7: deallocate space
                self.emit(Setw(dst=Reg(TMP), val=allocated_words))
                self.emit(Add(dst=Reg(SP), src1=Reg(SP), src2=Reg(TMP)))

                target
            } else if name == "@show" {
                match parameters {
                    [Reg(r)] => self.emit(LIR(Ctl(op=Show(r))))
                    [Mem(offset~)] => {
                        self.emit(Add(dst=Reg(TMP), src1=Mem(offset~), src2=Reg(Z)))
                        self.emit(LIR(Ctl(op=Show(TMP))))
                    }
                    _ => raise IRBuilderError("@show expects a single register/mem parameter, got: '\{parameters}'")
                }

                @asm.Loc::Unit
            } else {
                raise IRBuilderError("call to undeclared function '\{name}'")
            }
        }
        TAC::GetLocal(..) => {
            raise IRBuilderError("get_local outside of function body")
        }
        TAC::SetLocal(..) => {
            raise IRBuilderError("set_local outside of function body")
        }
        _ => raise IRBuilderError("not implemented: lower_expr for '\{item}'")
    }
}

// no hardware detection of stack overflow, adjust layout of data in 0x0000..0x7FFF to avoid collisions
// depending on program needs (max recursion depth * stack frame size)
pub const STACK_TOP: UInt16 = 0x7fff

pub fn PseudoBuilder::with_main_fn_call(self: PseudoBuilder) -> Array[@asm.PseudoInst] raise IRBuilderError {
    if self.functions.get("main") is Some(({ label_id, return_type })) {
        guard return_type == U16 else {
            raise IRBuilderError("The 'main' function must have return type 'u16', found '\{return_type}'")
        }

         [
            Directive(Origin(addr=@asm.PC_START_ADDR)),
            Setw(dst=Reg(SP), val=STACK_TOP),
            Jmp(dst=Label(label_id)),
        ] + self.insts
    } else {
        raise IRBuilderError("no 'main' function declared")
    }
}
