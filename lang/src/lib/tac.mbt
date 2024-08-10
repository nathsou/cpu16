// Three Address Code IR

pub type TACId UInt
pub type TACLabel UInt

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
    Label(TACLabel)
    Jump(~label: TACLabel, ~cond: TACVAlue)
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
        TAC::Label(label) => {
            "\{label}:"
        }
        TAC::Jump(~label, ~cond) => {
            "jump \{label} if \{cond}"
        }
    }
}

pub struct TACLowering {
    tac: Array[TAC]
    mut next_var_id: TACId
    mut next_label_id: TACLabel
}

pub fn TACLowering::new() -> TACLowering {
    {
        tac: [],
        next_var_id: 0U,
        next_label_id: 0U,
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

fn emit_label(self: TACLowering, label: TACLabel) -> Unit {
    self.emit(TAC::Label(label))
}

fn emit_jump(self: TACLowering, label: TACLabel, cond: TACVAlue) -> Unit {
    self.emit(TAC::Jump(~label, ~cond))
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
                    self.emit_jump(then_label, TACVAlue::Variable(not_cond_id))
                    let then = self.lower_expr(then_expr)
                    self.emit_assign(ret, then)
                    self.emit_jump(end_label, TACVAlue::Const(Const::Boolean(true)))
                    self.emit_label(then_label)
                    let else_ = self.lower_expr(else_expr)
                    self.emit_assign(ret, else_)
                    self.emit_label(end_label)
                }
                None => {
                    let skip_label = self.next_label()
                    self.emit_jump(skip_label, TACVAlue::Variable(not_cond_id))
                    let _ = self.lower_expr(then_expr)
                    self.emit_label(skip_label)
                }
            }

            TACVAlue::Variable(ret)
        }
    }
}
