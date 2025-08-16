
pub struct IRBuilder {
    mut next_var_id: @asm.IRVarId
    insts: Array[@asm.IR]
}

pub fn IRBuilder::new() -> IRBuilder {
    {
        next_var_id: 1U, // 0 is reserved for unit
        insts: [],
    }
}

pub fn IRBuilder::emit(self: IRBuilder, inst: @asm.IR) -> Unit {
    self.insts.push(inst)
}

suberror IRBuilderError String derive (Show)

fn next_var(self: IRBuilder) -> @asm.IRVarId {
    let var_id = self.next_var_id
    // Increment without relying on Add trait for IRVarId
    self.next_var_id = self.next_var_id.inner() + 1U
    var_id
}

pub fn lower_value(self: IRBuilder, value: TACValue, env: Env[TACId, @asm.IRVarId]) -> @asm.IRVarId raise IRBuilderError {
    match value {
        TACValue::Const(c) => {
            match c {
                Const::Integer(n, _) => {
                    let dst = self.next_var()
                    self.emit(@asm.IR::Set(dst~, val=n))
                    dst
                }
                Const::Boolean(q) => {
                    let dst = self.next_var()
                    self.emit(@asm.IR::Set(dst~, val=if q { 1 } else { 0 }))
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

fn get_or_declare(self: IRBuilder, env: Env[TACId, @asm.IRVarId], target: TACId) -> @asm.IRVarId {
    match env.lookup(target) {
        Some(dst) => dst
        None => {
            let dst = self.next_var()
            env.declare(target, dst)
            dst
        }
    }
}

let unit_var_id: @asm.IRVarId = 0U

pub fn IRBuilder::lower_expr(self: IRBuilder, expr: TAC, env: Env[TACId, @asm.IRVarId]) -> @asm.IRVarId raise IRBuilderError {
    match expr {
        TAC::Assign(target~, src~) => {
            let dst_id = self.get_or_declare(env, target)
            let src_id = self.lower_value(src, env)
            self.emit(@asm.IR::Move(dst=dst_id, src=src_id))
            dst_id
        }
        TAC::Unary(target~, op~, arg~) => {
            let dst = self.next_var()

            match op {
                UnaryOp::Not => {
                    let arg_id = self.lower_value(arg, env)
                    self.emit(@asm.IR::Not(dst~, src=arg_id))
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
                TACBinaryOp::Add => self.emit(@asm.IR::Add(dst~, src1=lhs_id, src2=rhs_id))
                TACBinaryOp::Sub => self.emit(@asm.IR::Sub(dst~, src1=lhs_id, src2=rhs_id))
                TACBinaryOp::Mul => self.emit(@asm.IR::Mul(dst~, src1=lhs_id, src2=rhs_id))
                TACBinaryOp::Div => self.emit(@asm.IR::Div(dst~, src1=lhs_id, src2=rhs_id))
                TACBinaryOp::Mod => self.emit(@asm.IR::Mod(dst~, src1=lhs_id, src2=rhs_id))
                TACBinaryOp::And => self.emit(@asm.IR::And(dst~, src1=lhs_id, src2=rhs_id))
                TACBinaryOp::Or => self.emit(@asm.IR::Or(dst~, src1=lhs_id, src2=rhs_id))
                TACBinaryOp::Xor => self.emit(@asm.IR::Xor(dst~, src1=lhs_id, src2=rhs_id))
            }

            env.declare(target, dst)
            dst
        }
        TAC::Store(dst~, src~, offset=_) => {
            let dst_id = self.get_or_declare(env, dst)
            let src_id = self.lower_value(src, env)
            self.emit(@asm.IR::Store(dst=dst_id, src=src_id))
            dst_id
        }
        TAC::Load(target~, addr~, offset=_) => {
            let target_id = self.get_or_declare(env, target)
            let addr_id = self.lower_value(addr, env)
            self.emit(@asm.IR::Load(dst=target_id, src=addr_id))
            target_id
        }
        TAC::Jump(label~) => {
            self.emit(@asm.IR::Jump(label~))
            unit_var_id
        }
        TAC::JumpIf(label~, cond~, lhs~, rhs~) => {
            let lhs_id = self.lower_value(lhs, env)
            let rhs_id = self.lower_value(rhs, env)
            self.emit(@asm.IR::JumpIf(label~, cond=cond, lhs=lhs_id, rhs=rhs_id))
            unit_var_id
        }
        TAC::Label(label~) => {
            self.emit(@asm.IR::Label(label))
            unit_var_id
        }
        _ => raise IRBuilderError("not implemented: lower_expr")
    }
}
