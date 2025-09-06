// Three Address Code IR

pub enum TACValue {
    Unit
    Const(Const)
    Variable(@asm.VarId)
}

pub enum TAC {
    Assign(target~: @asm.VarId, src~: TACValue)
    Unary(target~: @asm.VarId, op~: UnaryOp, arg~: TACValue)
    Binary(target~: @asm.VarId, lhs~: TACValue, op~: BinaryOp, rhs~: TACValue)
    Store(dst~: @asm.VarId, src~: TACValue, offset~: UInt)
    Load(target~: @asm.VarId, addr~: TACValue, offset~: UInt)
    Jump(label~: @asm.LabelId)
    JumpIf(label~: @asm.LabelId, cond~: @asm.JumpCond, lhs~: TACValue, rhs~: TACValue)
    Label(label~: @asm.LabelId)
    Func(name~: String, parameters~: Array[FunctionArgument], return_type~: Type, body~: Array[TAC])
    GetLocal(target~: @asm.VarId, index~: UInt)
    SetLocal(index~: UInt, src~: TACValue)
    Return(value~: Option[TACValue])
    Call(target~: @asm.VarId, name~: String, parameters~: Array[TACValue])
}

pub impl Show for TACValue with output(self, logger) {
    let output = match self {
        TACValue::Unit => "()"
        TACValue::Const(c) => c.to_string()
        TACValue::Variable(v) => v.to_string()
    }

    logger.write_string(output)
}

pub impl Show for TAC with output(self, logger) {
    let output = match self {
        TAC::Assign(target~, src~) => {
            "\{target} = \{src}"
        }
        TAC::Unary(target~, op~, arg~) => {
            "\{target} = \{op} \{arg}"
        }
        TAC::Binary(target~, lhs~, op~, rhs~) => {
            "\{target} = \{lhs} \{op} \{rhs}"
        }
        TAC::Store(dst~, src~, offset~) => {
            "store \{src} -> \{dst} + \{offset}"
        }
        TAC::Load(target~, addr~, offset~) => {
            "\{target} = load \{addr} + \{offset}"
        }
        TAC::JumpIf(label~, cond~, lhs~, rhs~) => {
            "jump \{label} if \{lhs} \{cond} \{rhs}"
        }
        TAC::Jump(label~) => {
            "jump \{label}"
        }
        TAC::Label(label~) => {
            "\{label}:"
        }
        TAC::GetLocal(target~, index~) => {
            "\{target} = get_local \{index}"
        }
        TAC::SetLocal(index~, src~) => {
            "set_local \{index} = \{src}"
        }
        TAC::Return(value~) => {
            match value {
                Some(value) => "return \{value}"
                None => "return"
            }
        }
        TAC::Func(name~, parameters~, return_type=_, body~) => {
            let args = []

            for param in parameters {
                args.push(param.name + ": " + param.ty.to_string())
            }

            let bodyStr = body.map(fn (tac) { "  " + tac.to_string() }).join("\n")
            "fn \{name} {\n" + bodyStr + "\n}"
        }
        TAC::Call(target~, name~, parameters~) => {
            let args = parameters.map(fn (param) { param.to_string() }).join(", ")
            "\{target} = call \{name}(\{args})"   
        }
    }

    logger.write_string(output)
}

pub struct TACBuilder {
    tac: Array[TAC]
    env: Env[String, @asm.VarId]
    functions: Env[String, @asm.LabelId]
    ctx: @asm.IdContext
}

pub fn TACBuilder::new(ctx: @asm.IdContext) -> TACBuilder {
    {
        tac: [],
        env: Env::new(),
        functions: Env::new(),
        ctx,
    }
}

fn child(self: TACBuilder) -> TACBuilder {
    {
        tac: [],
        env: self.env.child(),
        functions: self.functions,
        ctx: self.ctx,
    }
}

fn emit(self: TACBuilder, tac: TAC) -> Unit {
    self.tac.push(tac)
}

fn emit_assign(self: TACBuilder, target: @asm.VarId, src: TACValue) -> Unit {
    self.emit(TAC::Assign(target~, src~))
}

fn emit_unary_op(self: TACBuilder, target: @asm.VarId, op: UnaryOp, arg: TACValue) -> Unit {
    self.emit(TAC::Unary(target~, op~, arg~))
}

fn emit_binary_op(self: TACBuilder, target: @asm.VarId, lhs: TACValue, op: BinaryOp, rhs: TACValue) -> Unit {
    self.emit(TAC::Binary(target~, lhs~, op~, rhs~))
}

// removed unused emit_store / emit_load helpers

fn def_label(self: TACBuilder, label: @asm.LabelId) -> Unit {
    self.emit(TAC::Label(label~))
}

fn emit_jump_if(self: TACBuilder, label: @asm.LabelId, cond: @asm.JumpCond, lhs: TACValue, rhs: TACValue) -> Unit {
    self.emit(TAC::JumpIf(label~, cond~, lhs~, rhs~))
}

fn emit_jump(self: TACBuilder, label: @asm.LabelId) -> Unit {
    self.emit(TAC::Jump(label~))
}

fn emit_get_local(self: TACBuilder, target: @asm.VarId, index: UInt) -> Unit {
    self.emit(TAC::GetLocal(target~, index~))
}

// removed unused emit_set_local helper

fn emit_return(self: TACBuilder, value: Option[TACValue]) -> Unit {
    self.emit(TAC::Return(value~))
}

suberror TACLoweringError String derive (Show)

fn temp_get_comparison_cond(cond: Expr) -> (@asm.JumpCond, Expr, Expr) raise TACLoweringError {
        let (cond_op, cond_lhs, cond_rhs) = match cond {
        Expr::BinaryOp(lhs, op, rhs) => {
            match op {
                BinaryOp::Equ => (@asm.JumpCond::Equ, lhs, rhs)
                BinaryOp::Neq => (@asm.JumpCond::Neq, lhs, rhs)
                BinaryOp::Lss => (@asm.JumpCond::Lss, lhs, rhs)
                BinaryOp::Leq => (@asm.JumpCond::Leq, lhs, rhs)
                BinaryOp::Gtr => (@asm.JumpCond::Gtr, lhs, rhs)
                BinaryOp::Geq => (@asm.JumpCond::Geq, lhs, rhs)
                _ => {
                    println("expected comparison operator in condition")
                    raise TACLoweringError("expected comparison operator in condition")
                }
            }
        }
        _ => {
            println("TODO: implement if with non-comparison condition")
            raise TACLoweringError("TODO: implement conditions with non-comparison operators")
        }
    }

    (cond_op, cond_lhs, cond_rhs)
}

pub fn TACBuilder::lower_expr(self: TACBuilder, expr: Expr) -> TACValue raise TACLoweringError {
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
            let arg = self.lower_expr(arg)
            let target = self.ctx.next_var()
            self.emit_unary_op(target, op, arg)
            TACValue::Variable(target)
        }
        Expr::BinaryOp(lhs, op, rhs) => {
            let lhs = self.lower_expr(lhs)
            let rhs = self.lower_expr(rhs)
            let target = self.ctx.next_var()

            self.emit_binary_op(target, lhs, op, rhs)
            TACValue::Variable(target)
        }
        Expr::If(cond, then_expr, else_expr) => {
            let (cond_op, cond_lhs, cond_rhs) = temp_get_comparison_cond(cond)
            let cond_lhs = self.lower_expr(cond_lhs)
            let cond_rhs = self.lower_expr(cond_rhs)

            match else_expr {
                Some(else_expr) => {
                    let ret = self.ctx.next_var()
                    let then_label = self.ctx.next_label()
                    let end_label = self.ctx.next_label()
                    self.emit_jump_if(then_label, cond_op.negate(), cond_lhs, cond_rhs)
                    let then = self.lower_expr(then_expr)
                    self.emit_assign(ret, then)
                    self.emit_jump(end_label)
                    self.def_label(then_label)
                    let else_ = self.lower_expr(else_expr)
                    self.emit_assign(ret, else_)
                    self.def_label(end_label)
                    TACValue::Variable(ret)
                }
                None => {
                    let skip_label = self.ctx.next_label()
                    self.emit_jump_if(skip_label, cond_op.negate(), cond_lhs, cond_rhs)
                    let _ = self.lower_expr(then_expr)
                    self.def_label(skip_label)
                    TACValue::Unit
                }
            }
        }
        Expr::Block(body~, result~) => {
            for stmt in body {
                self.lower_stmt(stmt)
            }

            match result {
                Some(expr) => self.lower_expr(expr)
                None => TACValue::Unit
            }
        }
        Expr::Call(name, parameters) => {
            let args = []

            for param in parameters {
                args.push(self.lower_expr(param))
            }

            let target = self.ctx.next_var()
            self.emit(TAC::Call(target~, name~, parameters=args))
            TACValue::Variable(target)            
        }
    }
}

pub fn TACBuilder::lower_stmt(self: TACBuilder, stmt: Stmt) -> Unit raise TACLoweringError {
    match stmt {
        Stmt::Let(name~, mutable=_, value~) => {
            let value = self.lower_expr(value)
            match value {
                // TACValue::Variable(var_id) => {
                //     self.env.declare(name, var_id)
                // }
                _ => {
                    let var_id = self.ctx.next_var()
                    self.env.declare(name, var_id)
                    self.emit_assign(var_id, value)
                }
            }
        }
        Stmt::Semi(expr) => {
            let _ = self.lower_expr(expr)
        }
        Stmt::Assign(lhs~, rhs~) => {
            let rhs = self.lower_expr(rhs)

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
        Stmt::While(cond~, body~) => {
            let start_label = self.ctx.next_label()
            let end_label = self.ctx.next_label()
            self.def_label(start_label)
            let (cond_op, cond_lhs, cond_rhs) = temp_get_comparison_cond(cond)
            let cond_lhs = self.lower_expr(cond_lhs)
            let cond_rhs = self.lower_expr(cond_rhs)
            self.emit_jump_if(end_label, cond_op.negate(), cond_lhs, cond_rhs)

            for stmt in body {
                self.lower_stmt(stmt)
            }

            self.emit_jump(start_label)
            self.def_label(end_label)
        }
        Stmt::Return(value~) => {
            let value = match value {
                Some(value) => Some(self.lower_expr(value))
                None => None
            }

            self.emit_return(value)
        }
    }
}

pub fn TACBuilder::lower_decl(self: TACBuilder, decl: Decl) -> Unit raise TACLoweringError {
    match decl {
        Decl::Stmt(stmt) => self.lower_stmt(stmt)
        Decl::Func(name~, parameters~, return_type~, body~) => {
            let func_builder = self.child()

            for i, param in parameters {
                let var_id = self.ctx.next_var()
                func_builder.env.declare(param.name, var_id)
                func_builder.emit_get_local(var_id, i.reinterpret_as_uint())
            }

            for stmt in body {
                func_builder.lower_stmt(stmt)
            }

            self.emit(TAC::Func(name~, parameters~, return_type~, body=func_builder.tac))
        }
    }
}
