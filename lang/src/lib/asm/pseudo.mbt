
pub(all) enum PseudoInst {
    Halt
    Setz; Clrz
    Setc; Clrc
    Load(dst~: Loc, addr~: Loc)
    Store(dst~: Loc, src~: Loc)
    Move(dst~: Loc, src~: Loc)
    Cmp(src1~: Loc, src2~: Loc)
    Add(dst~: Loc, src1~: Loc, src2~: Loc)
    Sub(dst~: Loc, src1~: Loc, src2~: Loc)
    Adc(dst~: Loc, src1~: Loc, src2~: Loc)
    Sbc(dst~: Loc, src1~: Loc, src2~: Loc)
    Inc(dst~: Loc)
    Dec(dst~: Loc)
    Inc2(dst~: Loc, src~: Loc)
    Dec2(dst~: Loc, src~: Loc)
    And(dst~: Loc, src1~: Loc, src2~: Loc)
    Nand(dst~: Loc, src1~: Loc, src2~: Loc)
    Or(dst~: Loc, src1~: Loc, src2~: Loc)
    Xor(dst~: Loc, src1~: Loc, src2~: Loc)
    Shl(dst~: Loc, src~: Loc, amt~: Loc)
    Shr(dst~: Loc, src~: Loc, amt~: Loc)
    Not(dst~: Loc)
    Not2(dst~: Loc, src~: Loc)
    Jmp(dst~: Loc)
    Jeq(dst~: Loc, src1~: Loc, src2~: Loc)
    Jne(dst~: Loc, src1~: Loc, src2~: Loc)
    Jlt(dst~: Loc, src1~: Loc, src2~: Loc)
    Jgt(dst~: Loc, src1~: Loc, src2~: Loc)
    Jle(dst~: Loc, src1~: Loc, src2~: Loc)
    Jge(dst~: Loc, src1~: Loc, src2~: Loc)
    Jpc(dst~: Loc) // Jump on carry set
    Jpnc(dst~: Loc) // Jump on carry clear
    Jpz(dst~: Loc) // Jump on zero set
    Jpnz(dst~: Loc) // Jump on zero clear

    LIR(LIR)
} derive (Show)

pub fn lower(self: PseudoInst) -> Array[LIR] {
  match self {
    LIR(lir) => match lir {
      Set(dst~, val~) => {
        if val > 0x7ff {
          // TODO: Find the optimal set of instructions for a given `val`
          let high = (val >> 8) & 0xff
          let low = val & 0xff
          [
            Set(dst~, val=high),
            Set(dst=Reg(R5), val=8),
            Alu(dst~, src1=dst, src2=Reg(R5), op=Shl),
            Set(dst=Reg(R5), val=low),
            Alu(dst~, src1=dst, src2=Reg(R5), op=Or),
          ]
        } else {
          [lir]
        }
      }
      _ => [lir]
    }
    Halt => [Ctl(op=Halt)]
    Setz => [Ctl(op=Setz)]
    Clrz => [Ctl(op=Clrz)]
    Setc => [Ctl(op=Setc)]
    Clrc => [Ctl(op=Clrc)]
    // TODO: Support offsets
    Load(dst~, addr~) => [Mem(dst~, addr~, load=true, offset=0)]
    Store(dst~, src~) => [Mem(dst=src, addr=dst, load=false, offset=0)]
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
    Jpc(dst~) => [Jmp(dst~, cond=IfCarry)]
    Jpnc(dst~) => [Jmp(dst~, cond=IfNotCarry)]
    Jpz(dst~) => [Jmp(dst~, cond=IfZero)]
    Jpnz(dst~) => [Jmp(dst~, cond=IfNotZero)]
  }
}
