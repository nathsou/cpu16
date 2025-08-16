
pub fn assemble(source: String, verbose~: Bool) -> Bytes raise {
    let tokens = @lex.collect(source.to_lower(), next_token)
    let insts = parse(tokens)

    if verbose {
        println("Tokens:")

        for token in tokens {
            println(token)
        }

        println("\nInstructions:")

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
