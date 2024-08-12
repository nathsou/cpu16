
extern "js" fn write_file(file_path: String, contents: Array[UInt]) -> Unit =
  #|(file_path, contents) => {
  #|  Bun.write(file_path, new Uint16Array(contents.buf));
  #|}

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

    let lir_builder = @lib.LIRBuilder::from(ir_builder)

    for i = 0; i < ir_builder.insts.length(); i = i + 1 {
        let inst = ir_builder.insts[i]
        let _ = lir_builder.lower_ir!(inst)
    }

    println("\nLIR:")

    lir_builder.insts.iter().each(fn (inst) {
        println(@lib.LIR::to_string(inst))
    })

    lir_builder.remove_labels()
    let _ = lir_builder.allocate_registers(~regs_count=5)
    lir_builder.allocate()

    println("\nAllocated LIR:")

    for inst in lir_builder.insts {
        println(@lib.LIR::to_string(inst))
    }

    let insts = lir_builder.lower_lir!()

    println("\nInsts:")
    for inst in insts {
        println(@lib.Inst::to_string(inst))
    }

    let encoded = insts.map(fn (inst) {
        @lib.encode_inst(inst)
    })

    // write to file
    write_file("out.asm", encoded)
  } catch {
    err => {
      println(err)
    }
  }
}
