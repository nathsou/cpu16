
pub(all) enum PseudoInst {
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

    LIR(LIR)
}

pub fn lower(self: PseudoInst) -> Array[LIR] {
  match self {
    LIR(lir) => [lir]
    Add(dst~, src1~, src2~) => [LIR::Alu(dst~, src1~, src2~, op=AluOp::Add)]
    Sub(dst~, src1~, src2~) => [LIR::Alu(dst~, src1~, src2~, op=AluOp::Sub)]
    And(dst~, src1~, src2~) => [LIR::Alu(dst~, src1~, src2~, op=AluOp::And)]
    Adc(dst~, src1~, src2~) => [LIR::Alu(dst~, src1~, src2~, op=AluOp::Adc)]
    Sbc(dst~, src1~, src2~) => [LIR::Alu(dst~, src1~, src2~, op=AluOp::Sbc)]
    Inc(dst~) => [LIR::Alu(dst~, src1=dst, src2=Reg(Z), op=AluOp::Inc)]
    Dec(dst~) => [LIR::Alu(dst~, src1=dst, src2=Reg(Z), op=AluOp::Dec)]
    Inc2(dst~, src~) => [LIR::Alu(dst~, src1=src, src2=Reg(Z), op=AluOp::Inc)]
    Dec2(dst~, src~) => [LIR::Alu(dst~, src1=src, src2=Reg(Z), op=AluOp::Dec)]
    Nand(dst~, src1~, src2~) => [LIR::Alu(dst~, src1~, src2~, op=AluOp::Nand)]
    Or(dst~, src1~, src2~) => [LIR::Alu(dst~, src1~, src2~, op=AluOp::Or)]
    Xor(dst~, src1~, src2~) => [LIR::Alu(dst~, src1~, src2~, op=AluOp::Xor)]
    Shl(dst~, src~, amt~) => [LIR::Alu(dst~, src1=src, src2=amt, op=AluOp::Shl)]
    Shr(dst~, src~, amt~) => [LIR::Alu(dst~, src1=src, src2=amt, op=AluOp::Shr)]
    Not(dst~) => [LIR::Alu(dst~, src1=dst, src2=dst, op=AluOp::Nand)]
    Not2(dst~, src~) => [LIR::Alu(dst~, src1=src, src2=src, op=AluOp::Nand)]
  }
}
