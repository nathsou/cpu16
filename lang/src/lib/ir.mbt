
pub type IRVarId UInt derive (Show)

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
    Jump(~label_bb: Int)
    JumpIf(~label_bb: Int, ~cond: TACCond, ~lhs: IRVarId, ~rhs: IRVarId)
    Label(~bb: Int)
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

pub fn next_var(self: IRBuilder) -> IRVarId {
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
            env.bind(target, dst)
            dst
        }
    }
}

let unit_var_id: IRVarId = 0U

pub fn lower_expr(self: IRBuilder, expr: TACExpr, labels: Map[TACLabel, Int], env: Env[TACId, IRVarId]) -> IRVarId!IRBuilderError {
    match expr {
        TACExpr::Assign(~target, ~src) => {
            let dst_id = self.get_or_declare(env, target)
            let src_id = self.lower_value!(src, env)
            self.emit(IR::Move(~dst=dst_id, ~src=src_id))
            dst_id
        }
        TACExpr::Unary(~target, ~op, ~arg) => {
            let dst = self.next_var()

            match op {
                UnaryOp::Not => {
                    let arg_id = self.lower_value!(arg, env)
                    self.emit(IR::Not(~dst, ~src=arg_id))
                }
            }

            env.bind(target, dst)
            dst
        }
        TACExpr::Binary(~target, ~lhs, ~op, ~rhs) => {
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

            env.bind(target, dst)
            dst
        }
        TACExpr::Store(~dst, ~src) => {
            let dst_id = self.get_or_declare(env, dst)
            let src_id = self.lower_value!(src, env)
            self.emit(IR::Store(~dst=dst_id, ~src=src_id))
            dst_id
        }
        TACExpr::Load(~target, ~addr) => {
            let target_id = self.get_or_declare(env, target)
            let addr_id = self.lower_value!(addr, env)
            self.emit(IR::Load(~dst=target_id, ~src=addr_id))
            target_id
        }
        TACExpr::Jump(~label) => {
            let label_bb = labels[label].unwrap()
            self.emit(IR::Jump(~label_bb))
            unit_var_id
        }
        TACExpr::JumpIf(~label, ~cond, ~lhs, ~rhs) => {
            let label_bb = labels[label].unwrap()
            let lhs_id = self.lower_value!(lhs, env)
            let rhs_id = self.lower_value!(rhs, env)
            self.emit(IR::JumpIf(~label_bb, ~cond=cond, ~lhs=lhs_id, ~rhs=rhs_id))
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

pub fn lower_basic_blocks(basic_blocks: BasicBlocks) -> Array[IR]!IRBuilderError {
    let env = Env::new()
    let visited = @sorted_set.new()
    let ir_bbs: Map[Int, Array[IR]] = Map::new()
    let builder = IRBuilder::new()

    fn visit_bb(bb_idx: Int) -> Unit!IRBuilderError {
        if not(visited.contains(bb_idx)) {
            visited.add(bb_idx)
            let bb = basic_blocks.blocks[bb_idx]
            builder.emit(IR::Label(~bb=bb_idx))

            for i = 0; i < bb.predecessors.length(); i = i + 1 {
                visit_bb!(bb.predecessors[i])
            }

            builder.insts.clear()

            for i = 0; i < bb.instructions.length(); i = i + 1 {
                let inst = bb.instructions[i]
                let _ = builder.lower_expr!(inst, basic_blocks.labels, env)
            }

            ir_bbs[bb_idx] = builder.insts.copy()

            for i = 0; i < bb.successors.length(); i = i + 1 {
                visit_bb!(bb.successors[i])
            }
            
        }
    }

    visit_bb!(0)

    let instructions: Array[IR] = []

    for i = 0; i < basic_blocks.blocks.length(); i = i + 1 {
        match ir_bbs.get(i) {
            Some(insts) => {
                instructions.append(insts)
            }
            None => () // unreachable basic block
        }
    }

    instructions
}
