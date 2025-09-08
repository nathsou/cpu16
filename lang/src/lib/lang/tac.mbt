// Three Address Code IR

pub enum TACValue {
    Unit
    Const(Const)
    Variable(@asm.VarId)
}

pub struct TACFunc[T, V] {
    name: String
    parameters: Array[FunctionArgument]
    return_type: Type
    body: Array[TAC[T, V]]
}

pub enum TAC[Target, Value] {
    Assign(target~: Target, val~: Const)
    Move(target~: Target, src~: Target)
    Unary(target~: Target, op~: UnaryOp, arg~: Value)
    Binary(target~: Target, lhs~: Value, op~: BinaryOp, rhs~: Value)
    Store(dst~: Target, src~: Value, offset~: UInt)
    Load(target~: Target, addr~: Value, offset~: UInt)
    Jump(label~: @asm.LabelId)
    JumpIf(label~: @asm.LabelId, cond~: @asm.JumpCond, lhs~: Value, rhs~: Value)
    Label(label~: @asm.LabelId)
    Func(TACFunc[Target, Value])
    GetLocal(target~: Target, index~: UInt)
    SetLocal(index~: UInt, src~: Value)
    Return(value~: Value?)
    Call(target~: Target, name~: String, parameters~: Array[Value])
}

pub typealias TAC[@asm.VarId, TACValue] as TAC1
pub typealias TAC[@asm.VarId, @asm.VarId] as TAC2
pub typealias TAC[@asm.Reg, @asm.Reg] as TAC3

pub impl Show for TACValue with output(self, logger) {
    let output = match self {
        TACValue::Unit => "()"
        TACValue::Const(c) => c.to_string()
        TACValue::Variable(v) => v.to_string()
    }

    logger.write_string(output)
}

pub impl[T: Show, V: Show] Show for TAC[T, V] with output(self, logger) {
    let output = match self {
        TAC::Assign(target~, val~) => {
            "\{target} = \{val}"
        }
        TAC::Move(target~, src~) => {
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
        TAC::Func(f) => {
            let args = []

            for param in f.parameters {
                args.push(param.name + ": " + param.ty.to_string())
            }

            let bodyStr = f.body.map(fn (tac) { "  " + tac.to_string() }).join("\n")
            "fn \{f.name} {\n" + bodyStr + "\n}"
        }
        TAC::Call(target~, name~, parameters~) => {
            let args = parameters.map(fn (param) { param.to_string() }).join(", ")
            "\{target} = call \{name}(\{args})"
        }
    }

    logger.write_string(output)
}

pub fn[T, V] TACBuilder::functions(self: TACBuilder[T, V]) -> Iter[TACFunc[T, V]] {
    Iter::new(fn(visit: (TACFunc[T, V]) -> IterResult) -> IterResult {
        for item in self.tac {
            match item {
                TAC::Func(func) => {
                    guard visit(func) is IterContinue else { break IterEnd }
                }
                _ => ()
            }
        } else {
            IterContinue
        }
    })
}

pub struct TACBuilder[T, V] {
    tac: Array[TAC[T, V]]
    env: Env[String, @asm.VarId]
    ctx: @asm.IdContext
}

pub fn[T, V] TACBuilder::new(ctx: @asm.IdContext) -> TACBuilder[T, V] {
    {
        tac: [],
        env: Env::new(),
        ctx,
    }
}

fn[T, V] TACBuilder::child(self: TACBuilder[T, V]) -> TACBuilder[T, V] {
    {
        tac: [],
        env: self.env.child(),
        ctx: self.ctx,
    }
}

fn[T, V] TACBuilder::emit(self: TACBuilder[T, V], tac: TAC[T, V]) -> Unit {
    self.tac.push(tac)
}

fn[T, V] TACBuilder::emit_assign(self: TACBuilder[T, V], target: T, val: Const) -> Unit {
    self.emit(TAC::Assign(target~, val~))
}

fn TACBuilder::emit_assign_val(self: TACBuilder[@asm.VarId, TACValue], target: @asm.VarId, val: TACValue) -> Unit {
    match val {
        TACValue::Const(c) => self.emit_assign(target, c)
        TACValue::Variable(v) => self.emit_move(target, v)
        TACValue::Unit => ()
    }
}

fn[T, V] TACBuilder::emit_move(self: TACBuilder[T, V], target: T, src: T) -> Unit {
    self.emit(TAC::Move(target~, src~))
}

fn[T, V] TACBuilder::emit_unary_op(self: TACBuilder[T, V], target: T, op: UnaryOp, arg: V) -> Unit {
    self.emit(TAC::Unary(target~, op~, arg~))
}

fn[T, V] TACBuilder::emit_binary_op(self: TACBuilder[T, V], target: T, lhs: V, op: BinaryOp, rhs: V) -> Unit {
    self.emit(TAC::Binary(target~, lhs~, op~, rhs~))
}

// removed unused emit_store / emit_load helpers

fn[T, V] TACBuilder::def_label(self: TACBuilder[T, V], label: @asm.LabelId) -> Unit {
    self.emit(TAC::Label(label~))
}

fn[T, V] TACBuilder::emit_jump_if(self: TACBuilder[T, V], label: @asm.LabelId, cond: @asm.JumpCond, lhs: V, rhs: V) -> Unit {
    self.emit(TAC::JumpIf(label~, cond~, lhs~, rhs~))
}

fn[T, V] TACBuilder::emit_jump(self: TACBuilder[T, V], label: @asm.LabelId) -> Unit {
    self.emit(TAC::Jump(label~))
}

fn[T, V] TACBuilder::emit_get_local(self: TACBuilder[T, V], target: T, index: UInt) -> Unit {
    self.emit(TAC::GetLocal(target~, index~))
}

// removed unused emit_set_local helper

fn[T, V] TACBuilder::emit_return(self: TACBuilder[T, V], value: V?) -> Unit {
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

pub fn TACBuilder::lower_expr(self: TACBuilder[@asm.VarId, TACValue], expr: Expr) -> TACValue raise TACLoweringError {
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
                    self.emit_assign_val(ret, then)
                    self.emit_jump(end_label)
                    self.def_label(then_label)
                    let else_ = self.lower_expr(else_expr)
                    self.emit_assign_val(ret, else_)
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

pub fn TACBuilder::lower_stmt(self: TACBuilder[@asm.VarId, TACValue], stmt: Stmt) -> Unit raise TACLoweringError {
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
                    self.emit_assign_val(var_id, value)
                }
            }
        }
        Stmt::Expr(expr~, semicolon=_) => {
            let _ = self.lower_expr(expr)
        }
        Stmt::Assign(lhs~, rhs~) => {
            let rhs = self.lower_expr(rhs)

            match lhs {
                Expr::Var(name) => {
                    match self.env.lookup(name) {
                        Some(var_id) => self.emit_assign_val(var_id, rhs)
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

pub fn TACBuilder::lower_decl(self: TACBuilder[@asm.VarId, TACValue], decl: Decl) -> Unit raise TACLoweringError {
    match decl {
        Decl::Stmt(stmt) => self.lower_stmt(stmt)
        Decl::Func(name~, parameters~, return_type~, body~) => {
            let start_label = self.ctx.next_label()
            let func_builder = self.child()
            func_builder.def_label(start_label)

            for i, param in parameters {
                let var_id = self.ctx.next_var()
                func_builder.env.declare(param.name, var_id)
                func_builder.emit_get_local(var_id, i.reinterpret_as_uint())
            }

            for stmt in body {
                func_builder.lower_stmt(stmt)
            }

            self.emit(TAC::Func({ name, parameters, return_type, body: func_builder.tac }))
        }
    }
}

pub fn TACBuilder::lower_value(self: TACBuilder[@asm.VarId, @asm.VarId], value: TACValue) -> @asm.VarId {
    match value {
        TACValue::Unit => {
            UNIT_VAR_ID
        }
        TACValue::Const(c) => {
            let dst = self.ctx.next_var()
            self.emit_assign(dst, c)
            dst
        }
        TACValue::Variable(v) => v
    }
}

// Rewrite TAC to ensure that all operands are variables (no immediates)
pub fn TACBuilder::rewrite_immediates(self: TACBuilder[@asm.VarId, @asm.VarId], tac: Array[TAC1]) -> Unit {
    for item in tac {
        match item {
            TAC::Assign(target~, val~) => {
                self.emit_assign(target, val)
            }
            TAC::Move(target~, src~) => {
                self.emit_move(target, src)
            }
            TAC::Unary(target~, op~, arg~) => {
                let arg = self.lower_value(arg)
                self.emit_unary_op(target, op, arg)
            }
            TAC::Binary(target~, op~, lhs~, rhs~) => {
                let lhs = self.lower_value(lhs)
                let rhs = self.lower_value(rhs)
                self.emit_binary_op(target, lhs, op, rhs)
            }
            TAC::Store(dst~, src~, offset~) => {
                let src = self.lower_value(src)
                self.emit(TAC::Store(dst~, src~, offset~))
            }
            TAC::Load(target~, addr~, offset~) => {
                let addr = self.lower_value(addr)
                self.emit(TAC::Load(target~, addr~, offset~))
            }
            TAC::Jump(label~) => {
                self.emit_jump(label)
            }
            TAC::JumpIf(label~, cond~, lhs~, rhs~) => {
                let lhs = self.lower_value(lhs)
                let rhs = self.lower_value(rhs)
                self.emit_jump_if(label, cond, lhs, rhs)
            }
            TAC::Label(label~) => {
                self.def_label(label)
            }
            TAC::Func(f) => {
                let func_builder = self.child()
                func_builder.rewrite_immediates(f.body)
                self.emit(TAC::Func({
                    name: f.name,
                    parameters: f.parameters,
                    return_type: f.return_type,
                    body: func_builder.tac
                }))
            }
            TAC::GetLocal(target~, index~) => {
                self.emit_get_local(target, index)
            }
            TAC::SetLocal(index~, src~) => {
                let src = self.lower_value(src)
                self.emit(TAC::SetLocal(index~, src~))
            }
            TAC::Return(value~) => {
                let value = match value {
                    Some(value) => Some(self.lower_value(value))
                    None => None
                }

                self.emit_return(value)
            }
            TAC::Call(target~, name~, parameters~) => {
                let args: Array[@asm.VarId] = []

                for param in parameters {
                    args.push(self.lower_value(param))
                }

                self.emit(TAC::Call(target~, name~, parameters=args))
            }
        }
    }
}
