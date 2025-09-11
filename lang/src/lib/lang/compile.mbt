
pub fn compile(source: String, verbose~: Bool = false) -> Bytes raise {
    let tokens = @lex.collect(source, next_token)
    let parser = Parser::new(tokens)
    let decls = parser.parse_decls()
    let type_checker = TypeChecker::new()

    for decl in decls {
        let _ = type_checker.type_decl(decl)
    }

    let ctx = IdContext::new()
    let tac_builder = TACBuilder::new(ctx)

    for decl in decls {
        tac_builder.lower_decl(decl)
    }

    if verbose {
        println("[TAC]")

        for tac in tac_builder.tac {
            println(tac)
        }
    }

    let tac2 = {
        let builder = TACBuilder::new(ctx)
        builder.rewrite_immediates(tac_builder.tac)
        builder
    }

    if verbose {
        println("\n[TAC2]")

        for tac in tac2.tac {
            println(tac)
        }
    }

    let pseudo_builder = PseudoBuilder::new()
    let env = Env::new()
    let tac3 = tac2.to_tac3()

    if verbose {
        println("\n[TAC3]")

        for tac in tac3 {
            println(tac)
        }
    }

    for tac in tac3 {
        let _ = pseudo_builder.lower_tac(tac, env)
    }

    if verbose {
        println("\n[Pseudo]")
        for inst in pseudo_builder.insts {
            println(inst)
        }
    }

    let lir = @asm.lower_pseudo_to_lir(pseudo_builder.with_main_fn_call(), ctx~)

    if verbose {
        println("\n[LIR]")

        for inst in lir {
            println(inst)
        }
    }

    let lowered = @asm.lower_lir_to_insts(lir)

    if verbose {
        println("\n[ASM]")

        for inst in lowered.insts {
            println(inst)
        }
    }

    @asm.assemble(lowered.insts)
}
