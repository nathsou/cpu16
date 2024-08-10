// Three Address Code IR

pub type TACId UInt
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

pub enum TACVAlue {
    Const(Const)
    Variable(TACId)
}

pub enum TAC {
    Assign(~target: TACId, ~src: TACVAlue)
    Unary(~target: TACId, ~op: UnaryOp, ~arg: TACVAlue)
    Binary(~target: TACId, ~lhs: TACVAlue, ~op: BinaryOp, ~rhs: TACVAlue)
    Store(~dst: TACId, ~src: TACVAlue)
    Load(~target: TACId, ~addr: TACVAlue)
    CondJump(~label: TACLabel, ~cond: TACVAlue)
    Jump(~label: TACLabel)
}

pub fn to_string(self: TACVAlue) -> String {
    match self {
        TACVAlue::Const(c) => c.to_string()
        TACVAlue::Variable(v) => v.to_string()
    }
}

pub fn to_string(self: TAC) -> String {
    match self {
        TAC::Assign(~target, ~src) => {
            "\{target} = \{src}"
        }
        TAC::Unary(~target, ~op, ~arg) => {
            "\{target} = \{op} \{arg}"
        }
        TAC::Binary(~target, ~lhs, ~op, ~rhs) => {
            "\{target} = \{lhs} \{op} \{rhs}"
        }
        TAC::Store(~dst, ~src) => {
            "store \{src} -> \{dst}"
        }
        TAC::Load(~target, ~addr) => {
            "\{target} = load \{addr}"
        }
        TAC::CondJump(~label, ~cond) => {
            "jump \{label} if \{cond}"
        }
        TAC::Jump(~label) => {
            "jump \{label}"
        }
    }
}

pub struct TACLowering {
    tac: Array[TAC]
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

fn emit(self: TACLowering, tac: TAC) -> Unit {
    self.tac.push(tac)
}

fn emit_assign(self: TACLowering, target: TACId, src: TACVAlue) -> Unit {
    self.emit(TAC::Assign(~target, ~src))
}

fn emit_unary(self: TACLowering, target: TACId, op: UnaryOp, arg: TACVAlue) -> Unit {
    self.emit(TAC::Unary(~target, ~op, ~arg))
}

fn emit_binary(self: TACLowering, target: TACId, lhs: TACVAlue, op: BinaryOp, rhs: TACVAlue) -> Unit {
    self.emit(TAC::Binary(~target, ~lhs, ~op, ~rhs))
}

fn emit_store(self: TACLowering, dst: TACId, src: TACVAlue) -> Unit {
    self.emit(TAC::Store(~dst, ~src))
}

fn emit_load(self: TACLowering, target: TACId, addr: TACVAlue) -> Unit {
    self.emit(TAC::Load(~target, ~addr))
}

fn def_label(self: TACLowering, label: TACLabel) -> Unit {
    let pos = self.tac.length()
    self.label_pos[label] = pos
}

fn emit_jump(self: TACLowering, label: TACLabel, ~cond: Option[TACVAlue] = None) -> Unit {
    match cond {
        Some(cond) => {
            self.emit(TAC::CondJump(~label, ~cond))
        }
        None => {
            self.emit(TAC::Jump(~label))
        }
    }
}
pub fn lower_expr(self: TACLowering, expr: Expr) -> TACVAlue {
    match expr {
        Expr::Const(c) => {
            TACVAlue::Const(c)
        }
        Expr::UnaryOp(op, arg) => {
            let arg = self.lower_expr(arg)
            let target = self.next_var()
            self.emit_unary(target, op, arg)
            TACVAlue::Variable(target)
        }
        Expr::BinaryOp(lhs, op, rhs) => {
            let lhs = self.lower_expr(lhs)
            let rhs = self.lower_expr(rhs)
            let target = self.next_var()
            self.emit_binary(target, lhs, op, rhs)
            TACVAlue::Variable(target)
        }
        Expr::If(cond, then_expr, else_expr) => {
            let cond = self.lower_expr(cond)
            let not_cond_id = self.next_var()
            self.emit_unary(not_cond_id, UnaryOp::Not, cond)
            let ret = self.next_var()

            match else_expr {
                Some(else_expr) => {
                    let then_label = self.next_label()
                    let end_label = self.next_label()
                    self.emit_jump(then_label, ~cond=Some(TACVAlue::Variable(not_cond_id)))
                    let then = self.lower_expr(then_expr)
                    self.emit_assign(ret, then)
                    self.emit_jump(end_label, ~cond=None)
                    self.def_label(then_label)
                    let else_ = self.lower_expr(else_expr)
                    self.emit_assign(ret, else_)
                    self.def_label(end_label)
                }
                None => {
                    let skip_label = self.next_label()
                    self.emit_jump(skip_label, ~cond=Some(TACVAlue::Variable(not_cond_id)))
                    let _ = self.lower_expr(then_expr)
                    self.def_label(skip_label)
                }
            }

            TACVAlue::Variable(ret)
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
    instructions: ArrayView[TAC]
    successors: Array[Int]
    predecessors: Array[Int]
}

pub fn build_basic_blocks(self: TACLowering) -> Array[BasicBlock] {
    // identify leaders:
    let leaders = [0] // the first instruction is a leader

    // any instruction that follows a jump is a leader
    self.tac.iter().eachi(fn (idx, tac) {
        match tac {
            TAC::Jump(..) => {
                leaders.push(idx + 1)
            }
            TAC::CondJump(..) => {
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
    let blocks: Array[ArrayView[TAC]] = []

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
                TAC::Jump(~label) => {
                    // if the last instruction is an unconditional jump, the target is the successor
                    push_map(successors, i, label_block_index[label].unwrap())
                }
                TAC::CondJump(~label, ..) => {
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

    basic_blocks
}
