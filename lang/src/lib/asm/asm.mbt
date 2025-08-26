
pub fn assemble(source: String, verbose~: Bool) -> Bytes raise {
    let tokens = @lex.collect(source.to_lower(), next_token)
    let pseudo_insts = parse(tokens)
    let ctx: IdContext = {
        next_var_id: 0U, 
        next_label_id: 0U,
        fixed_temp_reg: true, // always use R5 for temporaries
    }

    let lir = lower_pseudo_to_lir(pseudo_insts, ctx~)
    let lowered = lower_lir_to_insts(lir, ctx~)

    if verbose {
        println("[Pseudo]")

        for inst in pseudo_insts {
            println(inst)
        }

        println("\n[LIR]")

        for inst in lir {
            println(inst)
        }

        println("\n[ASM]")

        for inst in lowered.insts {
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
