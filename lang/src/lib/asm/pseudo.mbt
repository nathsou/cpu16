
pub(all) enum PseudoInst {
    Halt
    Setz; Clrz // Set Zero Flag, Clear Zero Flag
    Setc; Clrc // Set Carry Flag, Clear Carry Flag
    Load(dst~: Loc, addr~: Loc, offset~: UInt16)
    Store(dst~: Loc, src~: Loc, offset~: UInt16)
    Move(dst~: Loc, src~: Loc)
    Cmp(src1~: Loc, src2~: Loc) // Compare
    Setw(dst~: Loc, val~: UInt16) // Set Word
    Add(dst~: Loc, src1~: Loc, src2~: Loc)
    Sub(dst~: Loc, src1~: Loc, src2~: Loc)
    Adc(dst~: Loc, src1~: Loc, src2~: Loc) // Add with Carry
    Sbc(dst~: Loc, src1~: Loc, src2~: Loc) // Subtract with Carry
    Inc(dst~: Loc) // Increment
    Dec(dst~: Loc) // Decrement
    Inc2(dst~: Loc, src~: Loc) // dst = src + 1
    Dec2(dst~: Loc, src~: Loc) // dst = src - 1
    And(dst~: Loc, src1~: Loc, src2~: Loc)
    Nand(dst~: Loc, src1~: Loc, src2~: Loc)
    Or(dst~: Loc, src1~: Loc, src2~: Loc)
    Xor(dst~: Loc, src1~: Loc, src2~: Loc)
    Shl(dst~: Loc, src~: Loc, amt~: Loc) // Shift Left
    Shr(dst~: Loc, src~: Loc, amt~: Loc) // Shift Right
    Not(dst~: Loc)
    Not2(dst~: Loc, src~: Loc) // dst = not src
    Jmp(dst~: Loc) // Jump
    Jeq(dst~: Loc, src1~: Loc, src2~: Loc) // Jump if Equal
    Jne(dst~: Loc, src1~: Loc, src2~: Loc) // Jump if Not Equal
    Jlt(dst~: Loc, src1~: Loc, src2~: Loc) // Jump if Less Than
    Jgt(dst~: Loc, src1~: Loc, src2~: Loc) // Jump if Greater Than
    Jle(dst~: Loc, src1~: Loc, src2~: Loc) // Jump if Less Than or Equal
    Jge(dst~: Loc, src1~: Loc, src2~: Loc) // Jump if Greater Than or Equal
    Jc(dst~: Loc) // Jump on carry set
    Jnc(dst~: Loc) // Jump on carry clear
    Jz(dst~: Loc) // Jump on zero set
    Jnz(dst~: Loc) // Jump on zero clear
    Push(val~: Loc) // Push value onto stack
    Pop(dst~: Loc) // Pop value from stack into dst
    Call(dst~: Loc) // Call subroutine
    Ret // Return from subroutine
    Nop // No Operation

    LIR(LIR)
    Directive(Directive)
} derive (Show)

pub suberror PseudoLoweringError String derive (Show)

pub fn PseudoInst::lower(self: PseudoInst) -> Array[LIR] raise PseudoLoweringError {
  match self {
    LIR(Set(dst=_, val~)) if val > 0x7ff => {
      raise PseudoLoweringError("`set` instruction value exceeds 11 bits: \{val}, use the `setw` pseudo-instruction instead")
    }
    LIR(lir) => [lir]
    Directive(dir) => [Directive(dir)]
    Halt => [Ctl(op=Halt)]
    Setz => [Ctl(op=Setz)]
    Clrz => [Ctl(op=Clrz)]
    Setc => [Ctl(op=Setc)]
    Clrc => [Ctl(op=Clrc)]
    Setw(dst~, val~) => {
        let val_uint = val.to_uint()

        // A fun little puzzle would be to find the optimal way (min instructions) to get to `val`
        if val <= 0x7ff {
            [Set(dst~, val~)]
        } else if val == 0xffff {
            [Alu(dst~, src1=Reg(Z), src2=Reg(Z), op=Dec)]
        } else if val >= (0xffff - 0x7ff) {
            let sub_val = (0x1000).to_uint16() - val

            [
                Set(dst=Reg(TMP), val=sub_val),
                Alu(dst~, src1=Reg(Z), src2=Reg(TMP), op=Sub),
            ]
        } else {
            // Check if `val` can be represented as a left shift of an 11-bit value
            {
                let shl_amount = val_uint.ctz()
                let shl_core = val_uint >> shl_amount
                
                if shl_core <= 0x7ff {
                    return [
                        Set(dst~, val=shl_core.reinterpret_as_int().to_uint16()),
                        Set(dst=Reg(TMP), val=shl_amount.to_uint16()),
                        Alu(dst~, src1=dst, src2=Reg(TMP), op=Shl),
                    ]
                }
            }

            // Fallback to a general strategy
            let high = (val >> 8) & 0xff
            let low = val & 0xff

            [
                Set(dst~, val=high),
                Set(dst=Reg(TMP), val=8),
                Alu(dst~, src1=dst, src2=Reg(TMP), op=Shl),
                Set(dst=Reg(TMP), val=low),
                Alu(dst~, src1=dst, src2=Reg(TMP), op=Or),
            ]
        }
    }
    // TODO: Support offsets
    Load(dst~, addr~, offset~) => [Mem(dst~, addr~, load=true, offset~)]
    Store(dst~, src~, offset~) => [Mem(dst=src, addr=dst, load=false, offset~)]
    Move(dst~, src~) => [Alu(dst~, src1=src, src2=Reg(Z), op=Add)]
    Cmp(src1~, src2~) => [Alu(dst=Reg(Z), src1~, src2~, op=Sub)]
    Add(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=Add)]
    Sub(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=Sub)]
    And(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=And)]
    Adc(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=Adc)]
    Sbc(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=Sbc)]
    Inc(dst~) => [Alu(dst~, src1=dst, src2=Reg(Z), op=Inc)]
    Dec(dst~) => [Alu(dst~, src1=dst, src2=Reg(Z), op=Dec)]
    Inc2(dst~, src~) => [Alu(dst~, src1=src, src2=Reg(Z), op=Inc)]
    Dec2(dst~, src~) => [Alu(dst~, src1=src, src2=Reg(Z), op=Dec)]
    Nand(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=Nand)]
    Or(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=Or)]
    Xor(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=Xor)]
    Shl(dst~, src~, amt~) => [Alu(dst~, src1=src, src2=amt, op=Shl)]
    Shr(dst~, src~, amt~) => [Alu(dst~, src1=src, src2=amt, op=Shr)]
    Not(dst~) => [Alu(dst~, src1=dst, src2=dst, op=Nand)]
    Not2(dst~, src~) => [Alu(dst~, src1=src, src2=src, op=Nand)]
    Jmp(dst~) => [Jmp(dst~, cond=Always)]
    Jeq(dst~, src1~, src2~) => [
      Alu(dst=Reg(Z), src1~, src2~, op=Sub),
      Jmp(dst~, cond=IfZero),
    ]
    Jne(dst~, src1~, src2~) => [
      Alu(dst=Reg(Z), src1~, src2~, op=Sub),
      Jmp(dst~, cond=IfNotZero),
    ]
    Jlt(dst~, src1~, src2~) => [
      Alu(dst=Reg(Z), src1~, src2~, op=Sub),
      Jmp(dst~, cond=IfNotCarry),
    ]
    Jgt(dst~, src1~, src2~) => [
      Alu(dst=Reg(Z), src1~, src2~, op=Sub),
      Jmp(dst~, cond=IfCarry),
    ]
    Jle(dst~, src1~, src2~) => [
      Alu(dst=Reg(Z), src1~, src2~, op=Sub),
      Jmp(dst~, cond=IfNotCarry),
    ]
    Jge(dst~, src1~, src2~) => [
      Alu(dst=Reg(Z), src1~, src2~, op=Sub),
      Jmp(dst~, cond=IfCarry),
    ]
    Jc(dst~) => [Jmp(dst~, cond=IfCarry)]
    Jnc(dst~) => [Jmp(dst~, cond=IfNotCarry)]
    Jz(dst~) => [Jmp(dst~, cond=IfZero)]
    Jnz(dst~) => [Jmp(dst~, cond=IfNotZero)]
    Push(val~) => [
        Store(dst=Reg(SP), src=val, offset=0),
        Dec(dst=Reg(SP)),
    ] |> lower_many()
    Pop(dst~) => [
        Inc(dst=Reg(SP)),
        Load(dst~, addr=Reg(SP), offset=0),
    ] |> lower_many()
    Call(dst~) => {
        [
            // skip next 5 instructions which are part of the call pseudo-instruction itself
            LIR(Set(dst=Reg(TMP), val=5)),
            Add(dst=Reg(TMP), src1=Reg(TMP), src2=Reg(PC)),
            Push(val=Reg(TMP)), // 2 instructions
            // TODO: Handle Jumps to arbitrary locations which might take more than 2 instructions
            Jmp(dst~), // 2 instructions
        ] |> lower_many()
    }
    Ret => [Pop(dst=Reg(PC))] |> lower_many()
    Nop => [Set(dst=Reg(Z), val=0)]
  }
}

fn lower_many(insts: Array[PseudoInst]) -> Array[LIR] raise PseudoLoweringError {
    insts.map(PseudoInst::lower).flatten()
}
