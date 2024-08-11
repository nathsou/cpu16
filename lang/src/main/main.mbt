fn main {
  try {
    let prog =
      #|if 3 + 7 == 21 {
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

    let tac_builder = @lib.TACBuilder::new()
    let tac_ret = tac_builder.lower_expr!(expr)

    println("\{expr}: \{ty}\n")

    println("TAC:")

    tac_builder.tac.iter().each(fn (tac) {
        println(@lib.TAC::to_string(tac))
    })

    println("\nret = \{tac_ret}")

    let ir_builder = @lib.IRBuilder::new()
    let env = @lib.Env::new()

    for i = 0; i < tac_builder.tac.length(); i = i + 1 {
        let tac = tac_builder.tac[i]
        let _ = ir_builder.lower_expr!(tac, env)
    }

    println("\nIR:")

    ir_builder.insts.iter().each(fn (inst) {
        println(@lib.IR::to_string(inst))
    })

    let lir_builder = @lib.LIRBuilder::new()

    for i = 0; i < ir_builder.insts.length(); i = i + 1 {
        let inst = ir_builder.insts[i]
        let _ = lir_builder.lower_ir!(inst)
    }

    println("\nLIR:")

    lir_builder.insts.iter().each(fn (inst) {
        println(@lib.LIR::to_string(inst))
    })

    let intervals = lir_builder.liveness_intervals()

    println("\nLiveness Intervals:")
    intervals.each(fn (key, val) {
        println("\{key}: \{val}")
    })

    let regs = lir_builder.allocate_registers(~regs_count=5)

    println("\nRegisters:")
    regs.each(fn (key, val) {
        println("\{key}: \{val}")
    })

    lir_builder.allocate()

    println("\nAllocated LIR:")
    lir_builder.insts.iter().each(fn (inst) {
        println(@lib.LIR::to_string(inst))
    })

  } catch {
    err => {
      println(err)
    }
  }
}
