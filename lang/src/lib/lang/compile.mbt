
pub fn compile(source: String, verbose~: Bool = false) -> Bytes raise {
    let tokens = @lex.collect(source, next_token)
    let parser = Parser::new(tokens)
    let decls = parser.parse_decls()
    let type_checker = TypeChecker::new()

    for decl in decls {
        let _ = type_checker.type_decl(decl)
    }

    let ctx = @asm.IdContext::new()
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

    let tac2: Array[TAC2] = {
        let builder = TACBuilder::new(ctx)
        builder.rewrite_immediates(tac_builder.tac)
        builder.tac
    }

    if verbose {
        println("\n[TAC2]")

        for tac in tac2 {
            println(tac)
        }
    }

    let pseudo_builder = PseudoBuilder::new()
    let env = Env::new()

    for tac in tac2 {
        let _ = pseudo_builder.lower_expr(tac, env)
    }

    if verbose {
        println("\n[Pseudo]")
        for inst in pseudo_builder.insts {
            println(inst)
        }
    }

    let lir = @asm.lower_pseudo_to_lir(pseudo_builder.with_main_fn_call())

    if verbose {
        println("\n[LIR]")

        for inst in lir {
            println(inst)
        }
    }

    let lowered = @asm.lower_lir_to_insts(lir)

    if verbose {
        println("\n[Allocation]")
        println(lowered.allocation)

        println("\n[Allocated LIR]")

        for inst in lowered.allocated {
            println(inst)
        }

        println("\n[ASM]")

        for inst in lowered.insts {
            println(inst)
        }
    }

    @asm.assemble(lowered.insts)
}
