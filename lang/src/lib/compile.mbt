pub fn compile(source: String, ~verbose: Bool = false) -> FixedArray[UInt]!Error {
  let lexer = Lexer::new(source)
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

  let parser = Parser::new(tokens)
  let stmts = parser.parse_stmts!()
  let type_checker = TypeChecker::new()

  for stmt in stmts {
    let _ = type_checker.type_stmt!(stmt)
  }

  let tac_builder = TACBuilder::new()
  
  for stmt in stmts {
    tac_builder.lower_stmt!(stmt)
  }

  if verbose {
    println("TAC:")

    for tac in tac_builder.tac {
      println(TAC::to_string(tac))
    }
  }

  let ir_builder = IRBuilder::new()
  let env = Env::new()

  for tac in tac_builder.tac {
    let _ = ir_builder.lower_expr!(tac, env)
  }

  if verbose {
    println("\nIR:")

    for inst in ir_builder.insts {
      println(IR::to_string(inst))
    }
  }

  let lir_builder = LIRBuilder::from(ir_builder)
  
  for inst in ir_builder.insts {
    let _ = lir_builder.lower_ir!(inst)
  }

  if verbose {
    println("\nLIR:")

    for inst in lir_builder.insts {
      println(LIR::to_string(inst))
    }
  }

  lir_builder.remove_labels()
  lir_builder.allocate()
  let insts = lir_builder.lower_lir!()

  if verbose {
    println("\nAllocated LIR:")

    for inst in insts {
      println(Inst::to_string(inst))
    }
  }

  let prog = FixedArray::make(65536, 0U)
  let start_addr = 0x8000

  for i, inst in insts {
    prog[start_addr + i] = encode_inst(inst)
  }

  prog
}
