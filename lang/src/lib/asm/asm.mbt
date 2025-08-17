
pub fn assemble(source: String, verbose~: Bool) -> Bytes raise {
    let tokens = @lex.collect(source.to_lower(), next_token)
    let pseudo_insts = parse(tokens)
    let lir_insts = pseudo_insts.map(PseudoInst::lower).flatten()
    let insts = LIRBuilder::lower(lir_insts, next_var_id=VarId(0), automatic_jump_temp_reg=false)

    if verbose {
        println("[Pseudo]")

        for inst in pseudo_insts {
            println(inst)
        }

        println("\n[LIR]")

        for inst in lir_insts {
            println(inst)
        }

        println("\n[ASM]")

        for inst in insts {
            println(inst)
        }
    }

    let buffer = @buffer.new(size_hint=insts.length() * 2)

    for inst in insts {
        let encoded = inst.encode()
        buffer.write_byte(encoded.to_byte())
        buffer.write_byte((encoded >> 8).to_byte())
    }

    buffer.to_bytes()
}
