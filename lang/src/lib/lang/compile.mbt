
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
            println(inst)
        }
    }
    
    let var_counter: @asm.VarIdCounter = {
        next_var_id: ir_builder.next_var_id,
        fixed_temp_reg: false, // Use next available general purpose register for temporaries
    }

    let pseudo = ir_builder.insts.map(@asm.lower_ir_to_pseudo)

    if verbose {
        println("\n[Pseudo]")
        for inst in pseudo {
            println(inst)
        }
    }

    let lir = @asm.lower_pseudo_to_lir(pseudo, var_counter~)

    if verbose {
        println("\n[LIR]")

        for inst in lir {
            println(inst)
        }
    }

    let lowered = @asm.lower_lir_to_insts(lir, var_counter~)

    if verbose {
        println("\n[Allocated LIR]")

        for inst in lowered.allocated {
            println(inst)
        }
    }

    let buffer = @buffer.new(size_hint=lowered.insts.length() * 2)

    for inst in lowered.insts {
        let encoded = inst.encode()
        buffer.write_byte(encoded.to_byte())
        buffer.write_byte((encoded >> 8).to_byte())
    }

    buffer.to_bytes()
}
