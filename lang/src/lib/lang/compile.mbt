
pub fn compile(source: String, verbose~: Bool = false) -> Bytes raise {
    let tokens = @lex.collect(source, next_token)
    let parser = Parser::new(tokens)
    let decls = parser.parse_decls()
    let type_checker = TypeChecker::new()

    for decl in decls {
        let _ = type_checker.type_decl(decl)
    }

    let ctx: @asm.IdContext = {
        next_var_id: 0U,
        next_label_id: 0U,
        fixed_temp_reg: false, // Use next available general purpose register for temporaries
    }

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

    let pseudo_builder = PseudoBuilder::new(ctx)
    let env = Env::new()

    for tac in tac_builder.tac {
        let _ = pseudo_builder.lower_expr(tac, env)
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

    let lowered = @asm.lower_lir_to_insts(lir, ctx~)

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
