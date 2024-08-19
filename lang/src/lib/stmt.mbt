
pub enum Stmt {
    Let(~name: String, ~mutable: Bool, ~value: Expr)
    // Expr(Expr) // expr without semicolon
    Semi(Expr) // expr with a trailing semicolon
    Assign(~lhs: Expr, ~rhs: Expr)
    While(~cond: Expr, ~body: Array[Stmt])
    Return(~value: Option[Expr])
}

fn show_stmts(stmts: Array[Stmt]) -> String {
    let s = []

    for stmt in stmts {
        s.push(stmt.to_string())
    }

    s.join("\n")
}

pub fn to_string(self: Stmt) -> String {
    match self {
        Stmt::Let(~name, ~mutable, ~value) => {
            let kw = if mutable { "var" } else { "let" }
            "\{kw} \{name} = \{value};"
        }
        // Stmt::Expr(expr) => expr.to_string()
        Stmt::Semi(expr) => "\{expr};"
        Stmt::Assign(~lhs, ~rhs) => "\{lhs} = \{rhs};"
        Stmt::While(~cond, ~body) => "while \{cond} \n{" + show_stmts(body) + "\n}"
        Stmt::Return(~value) => {
            match value {
                Some(expr) => "return \{expr};"
                None => "return;"
            }
        }
    }
}
