
pub enum Stmt {
    Let(~name: String, ~value: Expr)
    // Expr(Expr) // expr without semicolon
    Semi(Expr) // expr with a trailing semicolon
}

pub fn to_string(self: Stmt) -> String {
    match self {
        Stmt::Let(~name, ~value) => "let " + name + " = " + value.to_string() + ";"
        // Stmt::Expr(expr) => expr.to_string()
        Stmt::Semi(expr) => expr.to_string() + ";"
    }
}
