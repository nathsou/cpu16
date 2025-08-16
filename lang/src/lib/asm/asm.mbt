
pub fn assemble(source: String, verbose~: Bool) -> Bytes raise {
    let tokens = @lex.collect(source.to_lower(), next_token)
    let lir_insts = parse(tokens)
    let insts = LIRBuilder::lower(lir_insts, IRVarId(0))

    if verbose {
        println("Tokens:")

        for token in tokens {
            println(token)
        }

        println("\nLIR:")

        for inst in lir_insts {
            println(inst)
        }

        println("\nASM:")

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
