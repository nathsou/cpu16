
pub struct PseudoBuilder {
    mut next_var_id: @asm.VarId
    insts: Array[@asm.PseudoInst]
}

pub fn PseudoBuilder::new() -> PseudoBuilder {
    {
        next_var_id: 1U, // 0 is reserved for unit
        insts: [],
    }
}

pub fn PseudoBuilder::emit(self: PseudoBuilder, inst: @asm.PseudoInst) -> Unit {
    self.insts.push(inst)
}

suberror IRBuilderError String derive (Show)

fn next_var(self: PseudoBuilder) -> @asm.VarId {
    let var_id = self.next_var_id
    // Increment without relying on Add trait for IRVarId
    self.next_var_id = self.next_var_id.inner() + 1U
    var_id
}

pub fn PseudoBuilder::lower_value(self: PseudoBuilder, value: TACValue, env: Env[TACId, @asm.VarId]) -> @asm.VarId raise IRBuilderError {
    match value {
        TACValue::Const(c) => {
            match c {
                Const::Integer(n, _) => {
                    let dst = self.next_var()
                    self.emit(Setw(dst=Var(dst), val=n.to_uint16()))
                    dst
                }
                Const::Boolean(q) => {
                    let dst = self.next_var()
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

fn PseudoBuilder::get_or_declare(self: PseudoBuilder, env: Env[TACId, @asm.VarId], target: TACId) -> @asm.VarId {
    match env.lookup(target) {
        Some(dst) => dst
        None => {
            let dst = self.next_var()
            env.declare(target, dst)
            dst
        }
    }
}

let unit_var_id: @asm.VarId = 0U

pub fn PseudoBuilder::lower_expr(self: PseudoBuilder, expr: TAC, env: Env[TACId, @asm.VarId]) -> @asm.VarId raise IRBuilderError {
    match expr {
        TAC::Assign(target~, src~) => {
            let dst_id = self.get_or_declare(env, target)
            let src_id = self.lower_value(src, env)
            self.emit(Move(dst=Var(dst_id), src=Var(src_id)))
            dst_id
        }
        TAC::Unary(target~, op~, arg~) => {
            let dst = self.next_var()

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
            let dst = self.next_var()
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
            self.emit(Store(dst=Var(dst_id), src=Var(src_id)))
            dst_id
        }
        TAC::Load(target~, addr~, offset=_) => {
            let target_id = self.get_or_declare(env, target)
            let addr_id = self.lower_value(addr, env)
            self.emit(Load(dst=Var(target_id), addr=Var(addr_id)))
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
        _ => raise IRBuilderError("not implemented: lower_expr")
    }
}
