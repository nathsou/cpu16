// Three Address Code IR

pub type TACId UInt derive (Eq, Hash)
pub type TACLabel UInt derive (Eq, Hash)

fn op_add(self: TACId, other: TACId) -> TACId {
    self.0 + other.0
}

pub fn to_string(self: TACId) -> String {
    "%" + self.0.to_string()
}

fn op_add(self: TACLabel, other: TACLabel) -> TACLabel {
    self.0 + other.0
}

fn to_string(self: TACLabel) -> String {
    "L" + self.0.to_string()
}

pub enum TACValue {
    Const(Const)
    Variable(TACId)
}

pub enum TACBinaryOp {
    Add; Sub; Mul; Div; Mod
    And; Or; Xor
} derive (Show)

pub enum TACCond {
    Equ; Neq; Lss; Leq; Gtr; Geq
} derive (Show)

pub fn negate(self: TACCond) -> TACCond {
    match self {
        TACCond::Equ => TACCond::Neq
        TACCond::Neq => TACCond::Equ
        TACCond::Lss => TACCond::Geq
        TACCond::Leq => TACCond::Gtr
        TACCond::Gtr => TACCond::Leq
        TACCond::Geq => TACCond::Lss
    }
}

pub enum TACExpr {
    Assign(~target: TACId, ~src: TACValue)
    Unary(~target: TACId, ~op: UnaryOp, ~arg: TACValue)
    Binary(~target: TACId, ~lhs: TACValue, ~op: TACBinaryOp, ~rhs: TACValue)
    Store(~dst: TACId, ~src: TACValue)
    Load(~target: TACId, ~addr: TACValue)
    Jump(~label: TACLabel)
    JumpIf(~label: TACLabel, ~cond: TACCond, ~lhs: TACValue, ~rhs: TACValue)
}

pub fn to_string(self: TACValue) -> String {
    match self {
        TACValue::Const(c) => c.to_string()
        TACValue::Variable(v) => v.to_string()
    }
}

pub fn to_string(self: TACExpr) -> String {
    match self {
        TACExpr::Assign(~target, ~src) => {
            "\{target} = \{src}"
        }
        TACExpr::Unary(~target, ~op, ~arg) => {
            "\{target} = \{op} \{arg}"
        }
        TACExpr::Binary(~target, ~lhs, ~op, ~rhs) => {
            "\{target} = \{lhs} \{op} \{rhs}"
        }
        TACExpr::Store(~dst, ~src) => {
            "store \{src} -> \{dst}"
        }
        TACExpr::Load(~target, ~addr) => {
            "\{target} = load \{addr}"
        }
        TACExpr::JumpIf(~label, ~cond, ~lhs, ~rhs) => {
            "jump \{label} if \{lhs} \{cond} \{rhs}"
        }
        TACExpr::Jump(~label) => {
            "jump \{label}"
        }
    }
}

pub struct TACLowering {
    tac: Array[TACExpr]
    mut next_var_id: TACId
    mut next_label_id: TACLabel
    mut label_pos: Map[TACLabel, Int]
}

pub fn TACLowering::new() -> TACLowering {
    {
        tac: [],
        next_var_id: 0U,
        next_label_id: 0U,
        label_pos: Map::new(),
    }
}

fn next_var(self: TACLowering) -> TACId {
    let var_id = self.next_var_id
    self.next_var_id += 1U
    var_id
}

fn next_label(self: TACLowering) -> TACLabel {
    let label_id = self.next_label_id
    self.next_label_id += 1U
    label_id
}

fn emit(self: TACLowering, tac: TACExpr) -> Unit {
    self.tac.push(tac)
}

fn emit_assign(self: TACLowering, target: TACId, src: TACValue) -> Unit {
    self.emit(TACExpr::Assign(~target, ~src))
}

fn emit_unary_op(self: TACLowering, target: TACId, op: UnaryOp, arg: TACValue) -> Unit {
    self.emit(TACExpr::Unary(~target, ~op, ~arg))
}

fn emit_binary_op(self: TACLowering, target: TACId, lhs: TACValue, op: TACBinaryOp, rhs: TACValue) -> Unit {
    self.emit(TACExpr::Binary(~target, ~lhs, ~op, ~rhs))
}

fn emit_store(self: TACLowering, dst: TACId, src: TACValue) -> Unit {
    self.emit(TACExpr::Store(~dst, ~src))
}

fn emit_load(self: TACLowering, target: TACId, addr: TACValue) -> Unit {
    self.emit(TACExpr::Load(~target, ~addr))
}

fn def_label(self: TACLowering, label: TACLabel) -> Unit {
    let pos = self.tac.length()
    self.label_pos[label] = pos
}

fn emit_jump_if(self: TACLowering, label: TACLabel, cond: TACCond, lhs: TACValue, rhs: TACValue) -> Unit {
    self.emit(TACExpr::JumpIf(~label, ~cond, ~lhs, ~rhs))
}

fn emit_jump(self: TACLowering, label: TACLabel) -> Unit {
    self.emit(TACExpr::Jump(~label))
}

type! TACLoweringError String derive (Show)

pub fn lower_expr(self: TACLowering, expr: Expr) -> TACValue!TACLoweringError {
    match expr {
        Expr::Const(c) => {
            TACValue::Const(c)
        }
        Expr::UnaryOp(op, arg) => {
            let arg = self.lower_expr!(arg)
            let target = self.next_var()
            self.emit_unary_op(target, op, arg)
            TACValue::Variable(target)
        }
        Expr::BinaryOp(lhs, op, rhs) => {
            let lhs = self.lower_expr!(lhs)
            let rhs = self.lower_expr!(rhs)
            let target = self.next_var()

            let tac_binop = match op {
                BinaryOp::Add => TACBinaryOp::Add
                BinaryOp::Sub => TACBinaryOp::Sub
                BinaryOp::Mul => TACBinaryOp::Mul
                BinaryOp::Div => TACBinaryOp::Div
                BinaryOp::Mod => TACBinaryOp::Mod
                BinaryOp::And => TACBinaryOp::And
                BinaryOp::Or => TACBinaryOp::Or
                BinaryOp::Xor => TACBinaryOp::Xor
                _ => {
                    println("expected arithmetic or logical operator in binary expression, got: \{op}")
                    raise TACLoweringError("expected arithmetic or logical operator in binary expression")
                }
            }

            self.emit_binary_op(target, lhs, tac_binop, rhs)
            TACValue::Variable(target)
        }
        Expr::If(cond, then_expr, else_expr) => {
            let ret = self.next_var()

            let (cond_op, cond_lhs, cond_rhs) = match cond {
                Expr::BinaryOp(lhs, op, rhs) => {
                    match op {
                        BinaryOp::Equ => (TACCond::Equ, lhs, rhs)
                        BinaryOp::Neq => (TACCond::Neq, lhs, rhs)
                        BinaryOp::Lss => (TACCond::Lss, lhs, rhs)
                        BinaryOp::Leq => (TACCond::Leq, lhs, rhs)
                        BinaryOp::Gtr => (TACCond::Gtr, lhs, rhs)
                        BinaryOp::Geq => (TACCond::Geq, lhs, rhs)
                        _ => {
                            println("expected comparison operator in if condition")
                            raise TACLoweringError("expected comparison operator in if condition")
                        }
                    }
                }
                _ => {
                    println("TODO: implement if with non-comparison condition")
                    raise TACLoweringError("TODO: implement if with non-comparison condition")
                }
            }

            let cond_lhs = self.lower_expr!(cond_lhs)
            let cond_rhs = self.lower_expr!(cond_rhs)

            match else_expr {
                Some(else_expr) => {
                    let then_label = self.next_label()
                    let end_label = self.next_label()
                    self.emit_jump_if(then_label, cond_op.negate(), cond_lhs, cond_rhs)
                    let then = self.lower_expr!(then_expr)
                    self.emit_assign(ret, then)
                    self.emit_jump(end_label)
                    self.def_label(then_label)
                    let else_ = self.lower_expr!(else_expr)
                    self.emit_assign(ret, else_)
                    self.def_label(end_label)
                }
                None => {
                    let skip_label = self.next_label()
                    self.emit_jump_if(skip_label, cond_op.negate(), cond_lhs, cond_rhs)
                    let _ = self.lower_expr!(then_expr)
                    self.def_label(skip_label)
                }
            }

            TACValue::Variable(ret)
        }
    }
}

fn push_map[K: Eq + Hash, V](map: Map[K, Array[V]], key: K, value: V) -> Unit {
    match map.get(key) {
        Some(values) => {
            values.push(value)
        }
        None => {
            map[key] = [value]
        }
    }
}

pub struct BasicBlock {
    id: Int
    instructions: ArrayView[TACExpr]
    successors: Array[Int]
    predecessors: Array[Int]
}

pub struct BasicBlocks {
    blocks: Array[BasicBlock]
    labels: Map[TACLabel, Int]
}

pub fn build_basic_blocks(self: TACLowering) -> BasicBlocks {
    // identify leaders:
    let leaders = [0] // the first instruction is a leader

    // any instruction that follows a jump is a leader
    self.tac.iter().eachi(fn (idx, tac) {
        match tac {
            TACExpr::Jump(..) | TACExpr::JumpIf(..) => {
                leaders.push(idx + 1)
            }
            _ => ()
        }
    })

    // any instruction that is the target of a jump is a leader
    self.label_pos.iter().each(fn (pos) {
        leaders.push(pos.1)
    })

    leaders.dedup()

    // compute the basic block index for each label
    let label_block_index: Map[TACLabel, Int] = Map::new()

    fn get_label_block_index(label_pos: Int) -> Option[Int] {
        for i = 0; i < leaders.length(); i = i + 1 {
            let leader_pos = leaders[i]

            if leader_pos >= label_pos {
                return Some(i)
            }
        }

        None
    }

    self.label_pos.iter().each(fn (entry) {
        let label = entry.0
        let pos = entry.1
        match get_label_block_index(pos) {
            Some(block_index) => {
                label_block_index[label] = block_index
            }
            None => ()
        }
    })

    // Starting from a leader, the set of all following instructions until and not including
    // the next leader is the basic block corresponding to the starting leader
    let blocks: Array[ArrayView[TACExpr]] = []

    leaders.iter().eachi(fn (idx, leader) {
        match leaders.get(idx + 1) {
            Some(next_leader) => {
                blocks.push(self.tac[leader:next_leader])
            }
            None => {
                blocks.push(self.tac[leader:])
            }
        }
    })

    let successors: Map[Int, Array[Int]] = Map::new()

    for i = 0; i < blocks.length(); i = i + 1 {
        let block = blocks[i]
        if block.length() > 0 {
            match block[block.length() - 1] {
                TACExpr::Jump(~label) => {
                    // if the last instruction is an unconditional jump, the target is the successor
                    push_map(successors, i, label_block_index[label].unwrap())
                }
                TACExpr::JumpIf(~label, ..) => {
                    // if the last instruction is a conditional jump, the target and the next block are successors
                    push_map(successors, i, label_block_index[label].unwrap())

                    if i + 1 < blocks.length() {
                        push_map(successors, i, i + 1)
                    }
                }
                _ => {
                    // otherwise, the next block is the successor
                    if i + 1 < blocks.length() {
                        push_map(successors, i, i + 1)
                    }
                }
            }
        }
    }

    // compute predecessors (reverse of successors)
    let predecessors: Map[Int, Array[Int]] = Map::new()

    successors.iter().each(fn (entry) {
        let block_index = entry.0
        let succs = entry.1
        succs.iter().each(fn (succ) {
            push_map(predecessors, succ, block_index)
        })
    })
    
    // build basic blocks
    let basic_blocks: Array[BasicBlock] = []

    for i = 0; i < blocks.length(); i = i + 1 {
        let block = blocks[i]
        let successors = successors.get_or_default(i, [])
        let predecessors = predecessors.get_or_default(i, [])

        basic_blocks.push({
            id: i,
            instructions: block,
            successors,
            predecessors,
        })
    }

    {
        blocks: basic_blocks,
        labels: label_block_index,
    }
}
