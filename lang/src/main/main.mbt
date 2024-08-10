fn main {
  try {
    let prog =
      #|if 3 * 7 == 21 {
      #|  1 + 2 - 3
      #|} else {
      #|  4 + 5 + 6
      #|}

    let lexer = @lib.Lexer::new(prog)
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
    let type_checker = @lib.TypeChecker::new()
    let ty = type_checker.expr_type!(expr)

    println("\{expr}: \{ty}")
  } catch {
    err => {
      println(err)
    }
  }
}
