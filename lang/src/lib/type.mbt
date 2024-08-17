
pub enum Type {
    U8; U16; Bool; Unit
} derive (Show, Eq)

pub struct VarInfo {
    ty: Type
    mutable: Bool
}

pub struct TypeChecker {
    env: Env[String, VarInfo]
}

pub fn TypeChecker::new() -> TypeChecker {
    {
        env: Env::new()
    }
}

type! TypeError String derive (Show)

pub fn type_expr(self: TypeChecker, expr: Expr) -> Type!TypeError {
    match expr {
        Expr::Const(c) => match c {
            Const::Integer(_, kind) => match kind {
                IntKind::U8 => Type::U8
                IntKind::U16 => Type::U16
            }
            Const::Boolean(_) => Type::Bool
        }
        Expr::Var(name) => {
            match self.env.lookup(name) {
                Some({ ty, .. }) => ty
                None => raise TypeError("Undefined variable: '\{name}'")
            }
        }
        Expr::UnaryOp(op, rhs) => {
            let rhs_ty = self.type_expr!(rhs)

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
            let lhs_ty = self.type_expr!(lhs)
            let rhs_ty = self.type_expr!(rhs)

            match op {
                BinaryOp::Add | BinaryOp::Sub | BinaryOp::Mul | BinaryOp::Div | BinaryOp::Mod => {
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
                BinaryOp::Equ | BinaryOp::Neq | BinaryOp::Lss | BinaryOp::Leq | BinaryOp::Gtr | BinaryOp::Geq => {
                    if lhs_ty == rhs_ty {
                        Type::Bool
                    } else {
                        raise TypeError("expected operands of the same type in binary equality op")
                    }
                }
            }
        }
        Expr::If(cond, then_expr, else_expr) => {
            let cond_ty = self.type_expr!(cond)
            let then_ty = self.type_expr!(then_expr)

            if cond_ty == Type::Bool {
                match else_expr {
                    Some(else_expr) => {
                        let else_ty = self.type_expr!(else_expr)

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

pub fn type_stmt(self: TypeChecker, stmt: Stmt) -> Unit!TypeError {
    match stmt {
        Stmt::Let(~name, ~mutable, ~value) => {
            let valTy = self.type_expr!(value)
            self.env.bind(name, { ty: valTy, mutable })
        }
        Stmt::Semi(expr) => {
            let _ = self.type_expr!(expr)
        }
        Stmt::Assign(~lhs, ~rhs) => {
            match lhs {
                Expr::Var(name) => {
                    match self.env.lookup(name) {
                        Some({ ty, mutable }) => {
                            if mutable {
                                let rhsTy = self.type_expr!(rhs)

                                if ty != rhsTy {
                                    raise TypeError("Incompatible types in assignment for \{name}: '\{ty}' and '\{rhsTy}'")
                                }
                            } else {
                                raise TypeError("Cannot assign to immutable variable: '\{name}'")
                            }
                        }
                        None => raise TypeError("Undefined variable: '\{name}'")
                    }
                }
                _ => raise TypeError("Invalid assignment target: '\{lhs}'")
            }
        }
        Stmt::While(~cond, ~body) => {
            let condTy = self.type_expr!(cond)

            if condTy != Type::Bool {
                raise TypeError("expected boolean condition in while loop")
            }

            for stmt in body {
                self.type_stmt!(stmt)
            }
        }
    }
}
