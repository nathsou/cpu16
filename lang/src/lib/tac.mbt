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
    Store(~dst: TACId, ~src: TACValue, ~offset: UInt)
    Load(~target: TACId, ~addr: TACValue, ~offset: UInt)
    Jump(~label: TACLabel)
    JumpIf(~label: TACLabel, ~cond: TACCond, ~lhs: TACValue, ~rhs: TACValue)
    Label(~label: TACLabel)
    Func(~name: String, ~parameters: Array[FunctionArgument], ~return_type: Type, ~body: Array[TAC])
    GetLocal(~target: TACId, ~index: UInt)
    SetLocal(~index: UInt, ~src: TACValue)
    Return(~value: Option[TACValue])
    Call(~target: TACId, ~name: String, ~parameters: Array[TACValue])
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
        TAC::Store(~dst, ~src, ~offset) => {
            "store \{src} -> \{dst} + \{offset}"
        }
        TAC::Load(~target, ~addr, ~offset) => {
            "\{target} = load \{addr} + \{offset}"
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
        TAC::GetLocal(~target, ~index) => {
            "\{target} = get_local \{index}"
        }
        TAC::SetLocal(~index, ~src) => {
            "set_local \{index} = \{src}"
        }
        TAC::Return(~value) => {
            match value {
                Some(value) => "return \{value}"
                None => "return"
            }
        }
        TAC::Func(~name, ~parameters, ~return_type=_, ~body) => {
            let args = []

            for param in parameters {
                args.push(param.name + ": " + param.ty.to_string())
            }

            let bodyStr = body.map(fn (tac) { "  " + tac.to_string() }).join("\n")
            "fn \{name} {\n" + bodyStr + "\n}"
        }
        TAC::Call(~target, ~name, ~parameters) => {
            let args = parameters.map(fn (param) { param.to_string() }).join(", ")
            "\{target} = call \{name}(\{args})"   
        }
    }
}

pub struct TACBuilder {
    tac: Array[TAC]
    env: Env[String, TACId]
    functions: Env[String, TACLabel]
    mut next_label_id: TACLabel
}

pub fn TACBuilder::new() -> TACBuilder {
    {
        tac: [],
        env: Env::new(),
        functions: Env::new(),
        next_label_id: 0U,
    }
}

fn child(self: TACBuilder) -> TACBuilder {
    {
        tac: [],
        env: self.env.child(),
        functions: self.functions,
        next_label_id: self.next_label_id,
    }
}

let _next_var_id: Ref[TACId] = Ref::new(0U)

fn next_var_() -> TACId {
    let var_id = _next_var_id.val
    _next_var_id.val += 1U
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

fn emit_store(self: TACBuilder, dst: TACId, src: TACValue, offset: UInt) -> Unit {
    self.emit(TAC::Store(~dst, ~src, ~offset))
}

fn emit_load(self: TACBuilder, target: TACId, addr: TACValue, ~offset: UInt) -> Unit {
    self.emit(TAC::Load(~target, ~addr, ~offset))
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

fn emit_get_local(self: TACBuilder, target: TACId, index: UInt) -> Unit {
    self.emit(TAC::GetLocal(~target, ~index))
}

fn emit_set_local(self: TACBuilder, index: UInt, src: TACValue) -> Unit {
    self.emit(TAC::SetLocal(~index, ~src))
}

fn emit_return(self: TACBuilder, value: Option[TACValue]) -> Unit {
    self.emit(TAC::Return(~value))
}

type! TACLoweringError String derive (Show)

fn temp_get_comparison_cond(cond: Expr) -> (TACCond, Expr, Expr)!TACLoweringError {
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
            let target = next_var_()
            self.emit_unary_op(target, op, arg)
            TACValue::Variable(target)
        }
        Expr::BinaryOp(lhs, op, rhs) => {
            let lhs = self.lower_expr!(lhs)
            let rhs = self.lower_expr!(rhs)
            let target = next_var_()

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
            let (cond_op, cond_lhs, cond_rhs) = temp_get_comparison_cond!(cond)
            let cond_lhs = self.lower_expr!(cond_lhs)
            let cond_rhs = self.lower_expr!(cond_rhs)
            let ret = next_var_()

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
        Expr::Call(name, parameters) => {
            let args = []

            for param in parameters {
                args.push(self.lower_expr!(param))
            }

            let target = next_var_()
            self.emit(TAC::Call(~target, ~name, ~parameters=args))
            TACValue::Variable(target)            
        }
    }
}

pub fn lower_stmt(self: TACBuilder, stmt: Stmt) -> Unit!TACLoweringError {
    match stmt {
        Stmt::Let(~name, ~mutable=_, ~value) => {
            let value = self.lower_expr!(value)
            match value {
                TACValue::Variable(var_id) => {
                    self.env.declare(name, var_id)
                }
                _ => {
                    let var_id = next_var_()
                    self.env.declare(name, var_id)
                    self.emit_assign(var_id, value)
                }
            }
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
        Stmt::While(~cond, ~body) => {
            let start_label = self.next_label()
            let end_label = self.next_label()
            self.def_label(start_label)
            let (cond_op, cond_lhs, cond_rhs) = temp_get_comparison_cond!(cond)
            let cond_lhs = self.lower_expr!(cond_lhs)
            let cond_rhs = self.lower_expr!(cond_rhs)
            self.emit_jump_if(end_label, cond_op.negate(), cond_lhs, cond_rhs)

            for stmt in body {
                self.lower_stmt!(stmt)
            }

            self.emit_jump(start_label)
            self.def_label(end_label)
        }
        Stmt::Return(~value) => {
            let value = match value {
                Some(value) => Some(self.lower_expr!(value))
                None => None
            }

            self.emit_return(value)
        }
    }
}

pub fn lower_decl(self: TACBuilder, decl: Decl) -> Unit!TACLoweringError {
    match decl {
        Decl::Stmt(stmt) => self.lower_stmt!(stmt)
        Decl::Func(~name, ~parameters, ~return_type, ~body) => {
            let func_builder = self.child()

            for i, param in parameters {
                let var_id = next_var_()
                func_builder.env.declare(param.name, var_id)
                func_builder.emit_get_local(var_id, i.to_uint())
            }

            for stmt in body {
                func_builder.lower_stmt!(stmt)
            }

            self.emit(TAC::Func(~name, ~parameters, ~return_type, ~body=func_builder.tac))
        }
    }
}
