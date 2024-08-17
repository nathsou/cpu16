
pub enum Stmt {
    Let(~name: String, ~mutable: Bool, ~value: Expr)
    // Expr(Expr) // expr without semicolon
    Semi(Expr) // expr with a trailing semicolon
    Assign(~lhs: Expr, ~rhs: Expr)
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
    }
}
