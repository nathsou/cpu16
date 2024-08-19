
pub enum Type {
    U8; U16; Bool; Unit
} derive (Show, Eq)

pub fn word_size(self: Type) -> UInt {
    match self {
        Type::U8 => 1U
        Type::U16 => 1U
        Type::Bool => 1U
        Type::Unit => 0U
    }
}

pub struct VarInfo {
    ty: Type
    mutable: Bool
}

pub struct FuncInfo {
    parameters: Array[FunctionArgument]
    return_type: Type
}

pub struct TypeChecker {
    env_stack: Array[Env[String, VarInfo]]
    fun_stack: Array[Type] // return types
    functions: Env[String, FuncInfo]
}

pub fn TypeChecker::new() -> TypeChecker {
    {
        env_stack: [Env::new()],
        fun_stack: [],
        functions: Env::new()
    }
}

fn get_top_env_exn(self: TypeChecker) -> Env[String, VarInfo] {
    match self.env_stack.last() {
        Some(env) => env
        None => abort("empty env stack")
    }
}

fn lookup(self: TypeChecker, name: String) -> Option[VarInfo] {
    self.get_top_env_exn().lookup(name)
}

fn declare(self: TypeChecker, name: String, info: VarInfo) -> Unit {
    self.get_top_env_exn().declare(name, info)
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
            match self.lookup(name) {
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
        Expr::Call(name, args) => {
            match self.functions.lookup(name) {
                Some({ parameters, return_type }) => {
                    if args.length() == parameters.length() {
                        for i, param in parameters {
                            let arg_ty = self.type_expr!(args[i])

                            if arg_ty != param.ty {
                                let param_ty = param.ty
                                let param_name = param.name
                                raise TypeError("Expected '\{param_ty}' but got '\{arg_ty}' for parameter '\{param_name}'")
                            }
                        }

                        return_type
                    } else {
                        let expected_len = parameters.length()
                        let actual_len = args.length()
                        raise TypeError("Expected '\{expected_len}' arguments but got '\{actual_len}'")
                    }
                }
                None => raise TypeError("Undefined function: '\{name}'")
            }
        }
    }
}

pub fn type_stmt(self: TypeChecker, stmt: Stmt) -> Unit!TypeError {
    match stmt {
        Stmt::Let(~name, ~mutable, ~value) => {
            let valTy = self.type_expr!(value)
            self.declare(name, { ty: valTy, mutable })
        }
        Stmt::Semi(expr) => {
            let _ = self.type_expr!(expr)
        }
        Stmt::Assign(~lhs, ~rhs) => {
            match lhs {
                Expr::Var(name) => {
                    match self.lookup(name) {
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
                raise TypeError("Expected boolean condition in while loop")
            }

            for stmt in body {
                self.type_stmt!(stmt)
            }
        }
        Stmt::Return(~value) => {
            let expected_ret_ty = match self.fun_stack.last() {
                Some(ty) => ty
                None => raise TypeError("Return statement outside of function")
            }

            match value {
                Some(expr) => {
                    let actual_ret_ty = self.type_expr!(expr)

                    if expected_ret_ty != actual_ret_ty {
                        raise TypeError("Incompatible return type: expected '\{expected_ret_ty}' but got '\{actual_ret_ty}'")
                    }
                }
                None => if expected_ret_ty != Type::Unit {
                    raise TypeError("Expected return value in function with non-unit return type")
                }
            }
        }
    }
}

pub fn type_decl(self: TypeChecker, decl: Decl) -> Unit!TypeError {
    match decl {
        Decl::Func(~name, ~parameters, ~return_type, ~body) => {
            self.functions.declare(name, { parameters, return_type })
            self.env_stack.push(Env::new())
            self.fun_stack.push(return_type)

            for param in parameters {
                self.declare(param.name, { ty: param.ty, mutable: false })
            }

            for stmt in body {
                self.type_stmt!(stmt)
            }
            
            let _ = self.fun_stack.pop_exn()
            let _ = self.env_stack.pop_exn()
        }
        Decl::Stmt(stmt) => {
            self.type_stmt!(stmt)
        }
    }
}
