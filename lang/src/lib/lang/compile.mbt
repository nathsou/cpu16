
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

    let pseudo: PseudoBuilder[@asm.Reg] = {
        let builder = PseudoBuilder::new()

        for f in tac2.functions() {
            let _ = builder.lower(f)
        }

        builder
    }

    if verbose {
        println("\n[Pseudo]")
        
        for func in pseudo.functions.values() {
            println("<\{func.name}>")

            for inst in func.body {
                println(inst)
            }

            println("")
        }
    }

    let lir = @asm.lower_pseudo_to_lir(pseudo.with_main_fn_call(), ctx~)

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
