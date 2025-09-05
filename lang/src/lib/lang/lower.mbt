
pub struct PseudoBuilder {
    ctx: @asm.IdContext
    functions: Map[String, LowerFuncInfo]
    insts: Array[@asm.PseudoInst]
}

struct LowerFuncInfo {
    label_id: @asm.LabelId
    return_type: Type
}

pub fn PseudoBuilder::new(ctx: @asm.IdContext) -> PseudoBuilder {
    {
        ctx,
        functions: {},
        insts: [],
    }
}

pub fn PseudoBuilder::emit(self: PseudoBuilder, inst: @asm.PseudoInst) -> Unit {
    self.insts.push(inst)
}

suberror IRBuilderError String derive (Show)

pub fn PseudoBuilder::lower_value(self: PseudoBuilder, value: TACValue, env: Env[@asm.VarId, @asm.VarId]) -> @asm.VarId raise IRBuilderError {
    match value {
        TACValue::Const(c) => {
            match c {
                Const::Integer(n, _) => {
                    let dst = self.ctx.next_var()
                    self.emit(Setw(dst=Var(dst), val=n.to_uint16()))
                    dst
                }
                Const::Boolean(q) => {
                    let dst = self.ctx.next_var()
                    self.emit(Setw(dst=Var(dst), val=if q { 1 } else { 0 }))
                    dst
                }
            }
        }
        TACValue::Variable(v) => {
            match env.lookup(v) {
                Some(dst) => dst
                None => {
                    raise IRBuilderError("variable not found")
                }
            }
        }
    }
}

fn PseudoBuilder::get_or_declare(self: PseudoBuilder, env: Env[@asm.VarId, @asm.VarId], target: @asm.VarId) -> @asm.VarId {
    match env.lookup(target) {
        Some(dst) => dst
        None => {
            let dst = self.ctx.next_var()
            env.declare(target, dst)
            dst
        }
    }
}

let unit_var_id: @asm.VarId = 0U

pub fn PseudoBuilder::lower_expr(self: PseudoBuilder, expr: TAC, env: Env[@asm.VarId, @asm.VarId]) -> @asm.VarId raise IRBuilderError {
    match expr {
        TAC::Assign(target~, src~) => {
            let dst_id = self.get_or_declare(env, target)
            let src_id = self.lower_value(src, env)
            self.emit(Move(dst=Var(dst_id), src=Var(src_id)))
            dst_id
        }
        TAC::Unary(target~, op~, arg~) => {
            let dst = self.ctx.next_var()

            match op {
                UnaryOp::Not => {
                    let arg_id = self.lower_value(arg, env)
                    self.emit(Not2(dst=Var(dst), src=Var(arg_id)))
                }
            }

            env.declare(target, dst)
            dst
        }
        TAC::Binary(target~, lhs~, op~, rhs~) => {
            let dst = self.ctx.next_var()
            let lhs_id = self.lower_value(lhs, env)
            let rhs_id = self.lower_value(rhs, env)

            match op {
                Add => self.emit(Add(dst=Var(dst), src1=Var(lhs_id), src2=Var(rhs_id)))
                Sub => self.emit(Sub(dst=Var(dst), src1=Var(lhs_id), src2=Var(rhs_id)))
                Mul => raise IRBuilderError("multiplication not implemented")
                Div => raise IRBuilderError("division not implemented")
                Mod => raise IRBuilderError("modulo not implemented")
                And => self.emit(And(dst=Var(dst), src1=Var(lhs_id), src2=Var(rhs_id)))
                Or => self.emit(Or(dst=Var(dst), src1=Var(lhs_id), src2=Var(rhs_id)))
                Xor => self.emit(Xor(dst=Var(dst), src1=Var(lhs_id), src2=Var(rhs_id)))
            }

            env.declare(target, dst)
            dst
        }
        TAC::Store(dst~, src~, offset=_) => {
            let dst_id = self.get_or_declare(env, dst)
            let src_id = self.lower_value(src, env)
            self.emit(Store(dst=Var(dst_id), src=Var(src_id), offset=0))
            dst_id
        }
        TAC::Load(target~, addr~, offset=_) => {
            let target_id = self.get_or_declare(env, target)
            let addr_id = self.lower_value(addr, env)
            self.emit(Load(dst=Var(target_id), addr=Var(addr_id), offset=0))
            target_id
        }
        TAC::Jump(label~) => {
            self.emit(Jmp(dst=Label(label)))
            unit_var_id
        }
        TAC::JumpIf(label~, cond~, lhs~, rhs~) => {
            let lhs_id = self.lower_value(lhs, env)
            let rhs_id = self.lower_value(rhs, env)

            let pseudo: @asm.PseudoInst = match cond {
                Equ => Jeq(dst=Label(label), src1=Var(lhs_id), src2=Var(rhs_id))
                Neq => Jne(dst=Label(label), src1=Var(lhs_id), src2=Var(rhs_id))
                Lss => Jlt(dst=Label(label), src1=Var(lhs_id), src2=Var(rhs_id))
                Gtr => Jgt(dst=Label(label), src1=Var(lhs_id), src2=Var(rhs_id))
                Geq => Jge(dst=Label(label), src1=Var(lhs_id), src2=Var(rhs_id))
                Leq => Jle(dst=Label(label), src1=Var(lhs_id), src2=Var(rhs_id))
            }

            self.emit(pseudo)
            unit_var_id
        }
        TAC::Label(label~) => {
            self.emit(LIR(Label(label)))
            unit_var_id
        }
        TAC::Func(name~, parameters=_, return_type~, body~) => {
            let label_id = self.ctx.next_label()
            self.functions[name] = { return_type , label_id }

            self.emit(LIR(Label(label_id)))
            // save the return address
            let ret_addr = self.ctx.next_var()
            self.emit(Pop(dst=Var(ret_addr)))

            for inst in body {
                match inst {
                    GetLocal(target~, index~) => {
                        let target_id = self.get_or_declare(env, target)
                        // skip the 5 saved registers
                        self.emit(Load(dst=Var(target_id), addr=Reg(SP), offset=5 + index.reinterpret_as_int().to_uint16()))
                    }
                    SetLocal(index=_, src=_) => {
                        // let source_id = self.lower_value(src, env)
                        raise IRBuilderError("set_local not supported yet")
                    }
                    Return(value~) => {
                        if value is Some(v) {
                            let ret_id = self.lower_value(v, env)
                            self.emit(Push(val=Var(ret_id)))
                        }

                        self.emit(Move(dst=Reg(PC), src=Var(ret_addr)))
                    }
                    _ => {
                        let _ = self.lower_expr(inst, env)
                    }
                }
            }

            unit_var_id
        }
        TAC::Call(target~, name~, parameters~) => {
            if self.functions.get(name) is Some(({ label_id, return_type })) {
                guard return_type == U16 else {
                    raise IRBuilderError("function return type not supported for '\{name}': '\{return_type}'")
                }

                // TODO: Only save/restore registers that are used in the function body

                // step 1: Allocate space for registers (5), arguments (n)
                let allocated_words = (5 + parameters.length()).to_uint16()
                {
                    let tmp = self.ctx.next_var()
                    self.emit(Setw(dst=Var(tmp), val=allocated_words))
                    self.emit(Sub(dst=Reg(SP), src1=Reg(SP), src2=Var(tmp)))
                }

                // step 2: save r1-r5
                self.emit(Store(dst=Reg(SP), src=Reg(R1), offset=0))
                self.emit(Store(dst=Reg(SP), src=Reg(R2), offset=1))
                self.emit(Store(dst=Reg(SP), src=Reg(R3), offset=2))
                self.emit(Store(dst=Reg(SP), src=Reg(R4), offset=3))
                self.emit(Store(dst=Reg(SP), src=Reg(R5), offset=4))

                // step 3: push parameters
                for i in 0..<parameters.length() {
                    let param_id = self.lower_value(parameters[i], env)
                    self.emit(Store(dst=Reg(SP), src=Var(param_id), offset=(5 + i).to_uint16()))
                }

                // step 4: call the function 
                self.emit(Call(dst=Label(label_id)))
                let return_val_words = (if return_type is Unit { 0 } else { 1 }).to_uint16()

                // step 5: restore r1-r5
                self.emit(Load(dst=Reg(R1), addr=Reg(SP), offset=return_val_words + 0))
                self.emit(Load(dst=Reg(R2), addr=Reg(SP), offset=return_val_words + 1))
                self.emit(Load(dst=Reg(R3), addr=Reg(SP), offset=return_val_words + 2))
                self.emit(Load(dst=Reg(R4), addr=Reg(SP), offset=return_val_words + 3))
                self.emit(Load(dst=Reg(R5), addr=Reg(SP), offset=return_val_words + 4))

                // step 6: retrieve return value
                let target_id = if return_type is Unit {
                    unit_var_id
                } else {
                    let target_id = self.get_or_declare(env, target)
                    self.emit(Pop(dst=Var(target_id)))
                    target_id
                }

                // step 7: deallocate space
                {
                    let tmp = self.ctx.next_var()
                    self.emit(Setw(dst=Var(tmp), val=allocated_words))
                    self.emit(Add(dst=Reg(SP), src1=Reg(SP), src2=Var(tmp)))
                }

                target_id
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
        _ => raise IRBuilderError("not implemented: lower_expr for '\{expr}'")
    }
}

pub const STACK_TOP: UInt16 = 0xffff

pub fn PseudoBuilder::with_main_fn_call(self: PseudoBuilder) -> Array[@asm.PseudoInst] raise IRBuilderError {
    if self.functions.get("main") is Some(({ label_id, return_type })) {
        guard return_type == U16 else {
            raise IRBuilderError("The 'main' function must have return type 'u16', found '\{return_type}'")
        }

         [
            Setw(dst=Reg(SP), val=STACK_TOP),
            Call(dst=Label(label_id)),
            Halt
        ] + self.insts
    } else {
        raise IRBuilderError("no 'main' function declared")
    }
}
