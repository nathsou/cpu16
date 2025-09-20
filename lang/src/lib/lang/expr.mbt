
pub enum UnaryOp {
    Not
} derive (Show)

pub enum BinaryOp {
    Add; Sub; Mul; Div; Mod; Shl; Shr
    BitwiseAnd; BitwiseOr; BitwiseXor
    LogicalAnd; LogicalOr
    Equ; Neq; Lss; Gtr; Leq; Geq
}

pub impl Show for BinaryOp with output(self, logger) {
    let op_str = match self {
        Add => "+"
        Sub => "-"
        Mul => "*"
        Div => "/"
        Mod => "%"
        Shl => "<<"
        Shr => ">>"
        BitwiseAnd => "&"
        BitwiseOr => "|"
        BitwiseXor => "^"
        LogicalAnd => "&&"
        LogicalOr => "||"
        Equ => "=="
        Neq => "!="
        Lss => "<"
        Gtr => ">"
        Leq => "<="
        Geq => ">="
    }

    logger.write_string(op_str)
}

pub enum Const {
    Integer(Int, IntKind)
    Boolean(Bool)
}

pub impl Show for Const with output(self, logger) {
    let output = match self {
        Const::Integer(n, kind) => {
            match kind {
                IntKind::U8 => n.to_string() + "u8"
                IntKind::U16 => n.to_string() + "u16"
            }
        }
        Const::Boolean(q) => q.to_string()
    }

    logger.write_string(output)
}

pub enum Expr {
    Const(Const)
    Var(String)
    UnaryOp(UnaryOp, Expr)
    BinaryOp(Expr, BinaryOp, Expr)
    If(Expr, Expr, Expr?)
    Block(body~: Array[Stmt], result~: Expr?)
    Call(String, Array[Expr])
}

pub impl Show for Expr with output(self, logger) {
    let output = match self {
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

            "\{lhs} \{op} \{rhs}"
        }
        Expr::If(cond, then_expr, else_expr) => {
            let cond = cond.to_string()
            let then_expr = then_expr.to_string()
            match else_expr {
                Some(else_expr) => {
                    let else_expr = else_expr.to_string()
                    "if \{cond} \{then_expr} else \{else_expr}"
                }
                None => "if \{cond} \{then_expr}"
            }
        }
        Expr::Block(body~, result~) => {
            let body_str = show_stmts(body)
            match result {
                Some(expr) => {
                    let expr_str = expr.to_string()
                    "{\n\{body_str}\n\{expr_str}\n}"
                }
                None => "{\n\{body_str}\n}"
            }
        }
        Expr::Call(name, params) => {
            let params_str = params.map(param => param.to_string()).join(", ")
            "\{name}(\{params_str})"
        }
    }

    logger.write_string(output)
}
