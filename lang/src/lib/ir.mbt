
pub type IRVarId UInt derive (Show, Eq, Hash)

pub fn op_add(self: IRVarId, other: IRVarId) -> IRVarId {
    self.0 + other.0
}

pub enum IR {
    Set(~dst: IRVarId, ~val: Int)
    Load(~dst: IRVarId, ~src: IRVarId)
    Store(~dst: IRVarId, ~src: IRVarId)
    Move(~dst: IRVarId, ~src: IRVarId)
    Add(~dst: IRVarId, ~src1: IRVarId, ~src2: IRVarId)
    Sub(~dst: IRVarId, ~src1: IRVarId, ~src2: IRVarId)
    Mul(~dst: IRVarId, ~src1: IRVarId, ~src2: IRVarId)
    Div(~dst: IRVarId, ~src1: IRVarId, ~src2: IRVarId)
    Mod(~dst: IRVarId, ~src1: IRVarId, ~src2: IRVarId)
    Not(~dst: IRVarId, ~src: IRVarId)
    And(~dst: IRVarId, ~src1: IRVarId, ~src2: IRVarId)
    Or(~dst: IRVarId, ~src1: IRVarId, ~src2: IRVarId)
    Xor(~dst: IRVarId, ~src1: IRVarId, ~src2: IRVarId)
    Jump(~label: TACLabel)
    JumpIf(~label: TACLabel, ~cond: TACCond, ~lhs: IRVarId, ~rhs: IRVarId)
    Label(TACLabel)
} derive (Show)

pub struct IRBuilder {
    mut next_var_id: IRVarId
    insts: Array[IR]
}

pub fn IRBuilder::new() -> IRBuilder {
    {
        next_var_id: 1U, // 0 is reserved for unit
        insts: [],
    }
}

pub fn emit(self: IRBuilder, inst: IR) -> Unit {
    self.insts.push(inst)
}

type! IRBuilderError String derive (Show)

fn next_var(self: IRBuilder) -> IRVarId {
    let var_id = self.next_var_id
    self.next_var_id += 1U
    var_id
}

pub fn lower_value(self: IRBuilder, value: TACValue, env: Env[TACId, IRVarId]) -> IRVarId!IRBuilderError {
    match value {
        TACValue::Const(c) => {
            match c {
                Const::Integer(n, _) => {
                    let dst = self.next_var()
                    self.emit(IR::Set(~dst, ~val=n))
                    dst
                }
                Const::Boolean(q) => {
                    let dst = self.next_var()
                    self.emit(IR::Set(~dst, ~val=if q { 1 } else { 0 }))
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

fn get_or_declare(self: IRBuilder, env: Env[TACId, IRVarId], target: TACId) -> IRVarId {
    match env.lookup(target) {
        Some(dst) => dst
        None => {
            let dst = self.next_var()
            env.declare(target, dst)
            dst
        }
    }
}

let unit_var_id: IRVarId = 0U

pub fn lower_expr(self: IRBuilder, expr: TAC, env: Env[TACId, IRVarId]) -> IRVarId!IRBuilderError {
    match expr {
        TAC::Assign(~target, ~src) => {
            let dst_id = self.get_or_declare(env, target)
            let src_id = self.lower_value!(src, env)
            self.emit(IR::Move(~dst=dst_id, ~src=src_id))
            dst_id
        }
        TAC::Unary(~target, ~op, ~arg) => {
            let dst = self.next_var()

            match op {
                UnaryOp::Not => {
                    let arg_id = self.lower_value!(arg, env)
                    self.emit(IR::Not(~dst, ~src=arg_id))
                }
            }

            env.declare(target, dst)
            dst
        }
        TAC::Binary(~target, ~lhs, ~op, ~rhs) => {
            let dst = self.next_var()
            let lhs_id = self.lower_value!(lhs, env)
            let rhs_id = self.lower_value!(rhs, env)

            match op {
                TACBinaryOp::Add => self.emit(IR::Add(~dst, ~src1=lhs_id, ~src2=rhs_id))
                TACBinaryOp::Sub => self.emit(IR::Sub(~dst, ~src1=lhs_id, ~src2=rhs_id))
                TACBinaryOp::Mul => self.emit(IR::Mul(~dst, ~src1=lhs_id, ~src2=rhs_id))
                TACBinaryOp::Div => self.emit(IR::Div(~dst, ~src1=lhs_id, ~src2=rhs_id))
                TACBinaryOp::Mod => self.emit(IR::Mod(~dst, ~src1=lhs_id, ~src2=rhs_id))
                TACBinaryOp::And => self.emit(IR::And(~dst, ~src1=lhs_id, ~src2=rhs_id))
                TACBinaryOp::Or => self.emit(IR::Or(~dst, ~src1=lhs_id, ~src2=rhs_id))
                TACBinaryOp::Xor => self.emit(IR::Xor(~dst, ~src1=lhs_id, ~src2=rhs_id))
            }

            env.declare(target, dst)
            dst
        }
        TAC::Store(~dst, ~src) => {
            let dst_id = self.get_or_declare(env, dst)
            let src_id = self.lower_value!(src, env)
            self.emit(IR::Store(~dst=dst_id, ~src=src_id))
            dst_id
        }
        TAC::Load(~target, ~addr) => {
            let target_id = self.get_or_declare(env, target)
            let addr_id = self.lower_value!(addr, env)
            self.emit(IR::Load(~dst=target_id, ~src=addr_id))
            target_id
        }
        TAC::Jump(~label) => {
            self.emit(IR::Jump(~label))
            unit_var_id
        }
        TAC::JumpIf(~label, ~cond, ~lhs, ~rhs) => {
            let lhs_id = self.lower_value!(lhs, env)
            let rhs_id = self.lower_value!(rhs, env)
            self.emit(IR::JumpIf(~label, ~cond=cond, ~lhs=lhs_id, ~rhs=rhs_id))
            unit_var_id
        }
        TAC::Label(~label) => {
            self.emit(IR::Label(label))
            unit_var_id
        }
    }
}

pub struct IRBasicBlock {
    id: Int
    instructions: Array[IR]
    predecessors: Array[Int]
    successors: Array[Int]
    env: Env[TACId, IRVarId]
}
