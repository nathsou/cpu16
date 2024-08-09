fn main {
  let lexer = @lib.Lexer::new("if a == b { 1 } else { 0 }")
  let tokens = []

  while true {
    let token = lexer.next()

    match token {
      Some(t) => {
        tokens.push(t)
      }
      None => {
        break
      }
    }
  }

  println(tokens)
}
