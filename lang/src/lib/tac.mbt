// Three Address Code IR

pub type TACId UInt derive (Eq, Hash)
pub type TACLabel UInt derive (Eq, Hash, Show)

fn op_add(self: TACId, other: TACId) -> TACId {
    self.0 + other.0
}

pub fn to_string(self: TACId) -> String {
    "%" + self.0.to_string()
}

fn op_add(self: TACLabel, other: TACLabel) -> TACLabel {
    self.0 + other.0
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

pub enum TAC {
    Assign(~target: TACId, ~src: TACValue)
    Unary(~target: TACId, ~op: UnaryOp, ~arg: TACValue)
    Binary(~target: TACId, ~lhs: TACValue, ~op: TACBinaryOp, ~rhs: TACValue)
    Store(~dst: TACId, ~src: TACValue)
    Load(~target: TACId, ~addr: TACValue)
    Jump(~label: TACLabel)
    JumpIf(~label: TACLabel, ~cond: TACCond, ~lhs: TACValue, ~rhs: TACValue)
    Label(~label: TACLabel)
}

pub fn to_string(self: TACValue) -> String {
    match self {
        TACValue::Const(c) => c.to_string()
        TACValue::Variable(v) => v.to_string()
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
        TAC::JumpIf(~label, ~cond, ~lhs, ~rhs) => {
            "jump \{label} if \{lhs} \{cond} \{rhs}"
        }
        TAC::Jump(~label) => {
            "jump \{label}"
        }
        TAC::Label(~label) => {
            "\{label}:"
        }
    }
}

pub struct TACBuilder {
    tac: Array[TAC]
    env: Env[String, TACId]
    mut next_var_id: TACId
    mut next_label_id: TACLabel
}

pub fn TACBuilder::new() -> TACBuilder {
    {
        tac: [],
        env: Env::new(),
        next_var_id: 0U,
        next_label_id: 0U,
    }
}

fn next_var(self: TACBuilder) -> TACId {
    let var_id = self.next_var_id
    self.next_var_id += 1U
    var_id
}

fn next_label(self: TACBuilder) -> TACLabel {
    let label_id = self.next_label_id
    self.next_label_id += 1U
    label_id
}

fn emit(self: TACBuilder, tac: TAC) -> Unit {
    self.tac.push(tac)
}

fn emit_assign(self: TACBuilder, target: TACId, src: TACValue) -> Unit {
    self.emit(TAC::Assign(~target, ~src))
}

fn emit_unary_op(self: TACBuilder, target: TACId, op: UnaryOp, arg: TACValue) -> Unit {
    self.emit(TAC::Unary(~target, ~op, ~arg))
}

fn emit_binary_op(self: TACBuilder, target: TACId, lhs: TACValue, op: TACBinaryOp, rhs: TACValue) -> Unit {
    self.emit(TAC::Binary(~target, ~lhs, ~op, ~rhs))
}

fn emit_store(self: TACBuilder, dst: TACId, src: TACValue) -> Unit {
    self.emit(TAC::Store(~dst, ~src))
}

fn emit_load(self: TACBuilder, target: TACId, addr: TACValue) -> Unit {
    self.emit(TAC::Load(~target, ~addr))
}

fn def_label(self: TACBuilder, label: TACLabel) -> Unit {
    self.emit(TAC::Label(~label))
}

fn emit_jump_if(self: TACBuilder, label: TACLabel, cond: TACCond, lhs: TACValue, rhs: TACValue) -> Unit {
    self.emit(TAC::JumpIf(~label, ~cond, ~lhs, ~rhs))
}

fn emit_jump(self: TACBuilder, label: TACLabel) -> Unit {
    self.emit(TAC::Jump(~label))
}

type! TACLoweringError String derive (Show)

pub fn lower_expr(self: TACBuilder, expr: Expr) -> TACValue!TACLoweringError {
    match expr {
        Expr::Const(c) => {
            TACValue::Const(c)
        }
        Expr::Var(name) => {
            match self.env.lookup(name) {
                Some(var_id) => TACValue::Variable(var_id)
                None => {
                    raise TACLoweringError("undefined variable: '\{name}'")
                }
            }
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
            let ret = self.next_var()

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

pub fn lower_stmt(self: TACBuilder, stmt: Stmt) -> Unit!TACLoweringError {
    match stmt {
        Stmt::Let(~name, ~mutable=_, ~value) => {
            let value = self.lower_expr!(value)
            let var_id = self.next_var()
            self.env.bind(name, var_id)
            self.emit_assign(var_id, value)
        }
        Stmt::Semi(expr) => {
            let _ = self.lower_expr!(expr)
        }
        Stmt::Assign(~lhs, ~rhs) => {
            let rhs = self.lower_expr!(rhs)

            match lhs {
                Expr::Var(name) => {
                    match self.env.lookup(name) {
                        Some(var_id) => self.emit_assign(var_id, rhs)
                        None => {
                            raise TACLoweringError("undefined variable: '\{name}'")
                        }
                    }
                }
                _ => {
                    raise TACLoweringError("expected variable on the left-hand side of assignment")
                }
            }
        }
    }
}
