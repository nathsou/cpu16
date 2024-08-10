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
    let tac_lowering = @lib.TACLowering::new()
    let tac_ret = tac_lowering.lower_expr(expr)

    println("\{expr}: \{ty}\n")

    let tac_str = tac_lowering.tac.iter().map(fn (tac) {
      @lib.TAC::to_string(tac)
    }).collect()

    let mut last_index = 0

    println("start:")
    
    tac_lowering.label_pos.iter().each(fn (entry) {
      let label = entry.0
      let pos = entry.1

      for i = last_index; i < pos; i = i + 1 {
        println("  " + tac_str[i])
      }

      println("L" + label.0.to_string() + ":")

      last_index = pos
    })

    println("\nret = \{tac_ret}\n")

    let basic_blocks = tac_lowering.build_basic_blocks()

    for i = 0; i < basic_blocks.length(); i = i + 1 {
      println("basic block \{i}:")
      let bb = basic_blocks[i]

      for j = 0; j < bb.instructions.length(); j = j + 1 {
        println("  " + @lib.TAC::to_string(bb.instructions[j]))
      }
    }

  } catch {
    err => {
      println(err)
    }
  }
}
