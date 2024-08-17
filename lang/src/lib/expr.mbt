
pub enum UnaryOp {
    Not
} derive (Show)

pub enum BinaryOp {
    Add
    Sub
    Mul
    Div
    Mod
    And
    Or
    Xor
    Equ
    Neq
    Lss
    Gtr
    Leq
    Geq
} derive (Show)

pub enum Const {
    Integer(Int, IntKind)
    Boolean(Bool)
}

pub fn to_string(self: Const) -> String {
    match self {
        Const::Integer(n, kind) => {
            match kind {
                IntKind::U8 => n.to_string() + "u8"
                IntKind::U16 => n.to_string() + "u16"
            }
        }
        Const::Boolean(q) => q.to_string()
    }
}

pub enum Expr {
    Const(Const)
    Var(String)
    UnaryOp(UnaryOp, Expr)
    BinaryOp(Expr, BinaryOp, Expr)
    If(Expr, Expr, Option[Expr])
}

pub fn to_string(self: Expr) -> String {
    match self {
        Expr::Const(c) => c.to_string()
        Expr::Var(name) => name
        Expr::UnaryOp(op, arg) => {
            let arg = arg.to_string()
            match op {
                UnaryOp::Not => "!" + arg
            }
        }
        Expr::BinaryOp(lhs, op, rhs) => {
            let lhs = lhs.to_string()
            let rhs = rhs.to_string()
            match op {
                BinaryOp::Add => lhs + " + " + rhs
                BinaryOp::Sub => lhs + " - " + rhs
                BinaryOp::Mul => lhs + " * " + rhs
                BinaryOp::Div => lhs + " / " + rhs
                BinaryOp::Mod => lhs + " % " + rhs
                BinaryOp::And => lhs + " && " + rhs
                BinaryOp::Or => lhs + " || " + rhs
                BinaryOp::Xor => lhs + " ^ " + rhs
                BinaryOp::Equ => lhs + " == " + rhs
                BinaryOp::Neq => lhs + " != " + rhs
                BinaryOp::Lss => lhs + " < " + rhs
                BinaryOp::Gtr => lhs + " > " + rhs
                BinaryOp::Leq => lhs + " <= " + rhs
                BinaryOp::Geq => lhs + " >= " + rhs
            }
        }
        Expr::If(cond, then_expr, else_expr) => {
            let cond = cond.to_string()
            let then_expr = then_expr.to_string()
            match else_expr {
                Some(else_expr) => {
                    let else_expr = else_expr.to_string()
                    "if " + cond + " { " + then_expr + " } else { " + else_expr + " }"
                }
                None => "if " + cond + " { " + then_expr + " }"
            }
        }
    }
}
