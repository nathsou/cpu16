
pub fn compile(source: String, verbose~: Bool = false) -> Bytes raise {
    let tokens = @lex.collect(source, next_token)
    let parser = Parser::new(tokens)
    let decls = parser.parse_decls()
    let type_checker = TypeChecker::new()

    for decl in decls {
        let _ = type_checker.type_decl(decl)
    }

    let tac_builder = TACBuilder::new()

    for decl in decls {
        tac_builder.lower_decl(decl)
    }

    if verbose {
        println("[TAC]")

        for tac in tac_builder.tac {
            println(TAC::to_string(tac))
        }
    }

    let ir_builder = IRBuilder::new()
    let env = Env::new()

    for tac in tac_builder.tac {
        let _ = ir_builder.lower_expr(tac, env)
    }

    if verbose {
        println("\n[IR]")

        for inst in ir_builder.insts {
            println(@asm.IR::to_string(inst))
        }
    }

    let lir_builder = @asm.LIRBuilder::new(ir_builder.next_var_id)

    for inst in ir_builder.insts {
        let _ = lir_builder.lower_ir(inst)
    }

    if verbose {
        println("\n[LIR]")

        for inst in lir_builder.insts {
            println(@asm.LIR::to_string(inst))
        }
    }

    lir_builder.remove_labels(automatic_jump_temp_reg=true)
    lir_builder.allocate()
    let insts = lir_builder.lower_lir()

    if verbose {
        println("\n[Allocated LIR]")

        for inst in insts {
            println(@asm.Inst::to_string(inst))
        }
    }

    let prog = @buffer.new()

    for inst in insts {
        prog.write_byte(@asm.Inst::encode(inst).to_byte())
    }

    prog.to_bytes()
}
