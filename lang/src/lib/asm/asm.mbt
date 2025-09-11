
pub const PC_START_ADDR: UInt16 = 0x8000

pub fn assemble(insts: Array[InstOrDirective]) -> Bytes {
    let bytes: FixedArray[Byte] = FixedArray::make(128 * 1024, 0) // 64 * 16 bits (128KB)
    let mut offset = 0

    for inst_or_directive in insts {
        match inst_or_directive {
            Inst(inst) => {
                let encoded = inst.encode()
                bytes[offset] = encoded.to_byte()
                bytes[offset + 1] = (encoded >> 8).to_byte()
                offset += 2
            }
            Directive(directive) => {
                match directive {
                    Origin(addr~) => {
                        offset = addr.to_int() * 2 // each instruction is 2 bytes
                    }
                }
            }
        }
    }

    @bytes.from_fixedarray(bytes)
}

pub fn assemble_source(source: String, verbose~: Bool) -> Bytes raise {
    let tokens = @lex.collect(source.to_lower(), next_token)
    let { pseudo, next_label_id } = parse(tokens)
    let ctx: LabelContextImpl = { next_id: next_label_id }
    let lir = lower_pseudo_to_lir(pseudo, ctx~)
    let lowered = lower_lir_to_insts(lir)

    if verbose {
        println("[Pseudo]")

        for inst in pseudo {
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

    assemble(lowered.insts)
}
