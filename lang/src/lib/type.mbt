
pub enum Type {
    U8; U16; Bool; Unit
} derive (Show, Eq)

type TypeEnv Env[Type]

pub struct TypeChecker {
    env: TypeEnv
}

pub fn TypeChecker::new() -> TypeChecker {
    {
        env: Env::new()
    }
}

type! TypeError String derive (Show)
pub fn expr_type(self: TypeChecker, expr: Expr) -> Type!TypeError {
    match expr {
        Expr::Const(c) => match c {
            Const::Integer(_, kind) => match kind {
                IntKind::U8 => Type::U8
                IntKind::U16 => Type::U16
            }
            Const::Boolean(_) => Type::Bool
        }
        Expr::UnaryOp(op, rhs) => {
            let rhs_ty = self.expr_type!(rhs)

            match op {
                UnaryOp::Not => {
                    if rhs_ty == Type::Bool {
                        Type::Bool
                    } else {
                        raise TypeError("expected boolean in unary not")
                    }
                }
            }
        }
        Expr::BinaryOp(lhs, op, rhs) => {
            let lhs_ty = self.expr_type!(lhs)
            let rhs_ty = self.expr_type!(rhs)

            match op {
                BinaryOp::Add | BinaryOp::Sub | BinaryOp::Mul | BinaryOp::Div | BinaryOp::Mod |
                BinaryOp::Lss | BinaryOp::Gtr | BinaryOp::Leq | BinaryOp::Geq => {  
                    if lhs_ty == Type::U8 && rhs_ty == Type::U8 {
                        Type::U8
                    } else if lhs_ty == Type::U16 && rhs_ty == Type::U16 {
                        Type::U16
                    } else {
                        raise TypeError("expected integer operands in binary arithmetic op")
                    }
                }
                BinaryOp::And | BinaryOp::Or | BinaryOp::Xor => {
                    if lhs_ty == Type::Bool && rhs_ty == Type::Bool {
                        Type::Bool
                    } else {
                        raise TypeError("expected boolean operands in binary logical op")
                    }
                }
                BinaryOp::Eq | BinaryOp::Neq => {
                    if lhs_ty == rhs_ty {
                        Type::Bool
                    } else {
                        raise TypeError("expected operands of the same type in binary equality op")
                    }
                }
            }
        }
        Expr::If(cond, then_expr, else_expr) => {
            let cond_ty = self.expr_type!(cond)
            let then_ty = self.expr_type!(then_expr)

            if cond_ty == Type::Bool {
                match else_expr {
                    Some(else_expr) => {
                        let else_ty = self.expr_type!(else_expr)

                        if then_ty == else_ty {
                            then_ty
                        } else {
                            raise TypeError("expected then and else branches to have the same type in if expression")
                        }
                    }
                    None => if then_ty == Type::Unit {
                        Type::Unit
                    } else {
                        raise TypeError("expected then branch to have unit type in if expression")
                    }
                }
            } else {
                raise TypeError("expected boolean condition in if expression")
            }
        }
    }
}
