fn main {
  try {
    let lexer = @lib.Lexer::new("31 + 7 + 1 - (2 * 11)")
    let tokens = []
    
    while true {
      let token = lexer.next!()

      match token {
        Some(t) => {
          tokens.push(t)
        }
        None => {
          break
        }
      }
    }

    let parser = @lib.Parser::new(tokens)
    let expr = parser.parse_expr!()

    println(expr)
  } catch {
    err => {
      println(err)
    }
  }
}
