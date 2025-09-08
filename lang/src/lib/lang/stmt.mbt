
pub enum Stmt {
    Let(name~: String, mutable~: Bool, value~: Expr)
    Expr(expr~: Expr, semicolon~: Bool)
    Assign(lhs~: Expr, rhs~: Expr)
    While(cond~: Expr, body~: Array[Stmt])
    Return(value~: Option[Expr])
}

fn show_stmts(stmts: Array[Stmt]) -> String {
    let s = []

    for stmt in stmts {
        s.push(stmt.to_string())
    }

    s.join("\n")
}

pub impl Show for Stmt with output(self, logger) {
    let output = match self {
        Stmt::Let(name~, mutable~, value~) => {
            let kw = if mutable { "var" } else { "let" }
            "\{kw} \{name} = \{value};"
        }
        Stmt::Expr(expr~, semicolon~) => "\{expr}" + (if semicolon { ";" } else { "" })
        Stmt::Assign(lhs~, rhs~) => "\{lhs} = \{rhs};"
        Stmt::While(cond~, body~) => "while \{cond} \n{" + show_stmts(body) + "\n}"
        Stmt::Return(value~) => {
            match value {
                Some(expr) => "return \{expr};"
                None => "return;"
            }
        }
    }

    logger.write_string(output)
}
