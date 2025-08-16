
pub(all) enum Reg {
  Z; R1; R2; R3; R4; R5; SP; PC
} derive (Show, Eq)

pub(all) enum ControlOp {
    Halt
    Setz
    Clrz
    Setc
    Clrc
    Restore
} derive (Show, Eq)

pub(all) enum AluOp {
  Add; Sub; Adc; Sbc;
  AddIfZero; SubIfZero; AdcIfZero; SbcIfZero;
  AddIfNotZero; SubIfNotZero; AdcIfNotZero; SbcIfNotZero;
  AddIfCarry; SubIfCarry; AdcIfCarry; SbcIfCarry;
  AddIfNotCarry; SubIfNotCarry; AdcIfNotCarry; SbcIfNotCarry;
  Inc; Dec;
  And; Nand; Or; Xor; Shl; Shr
} derive (Show, Eq)

pub(all) enum Inst {
  Ctl(op~: ControlOp)
  Set(dst~: Reg, val~: UInt)
  Mem(dst~: Reg, addr~: Reg, load~: Bool, offset~: UInt)
  Alu(dst~: Reg, src1~: Reg, src2~: Reg, op~: AluOp)
} derive (Show)

pub trait Encode {
  encode(Self) -> UInt
}

pub trait Decode {
  decode(UInt) -> Self?
}

impl Encode for Reg with encode(reg) -> UInt {
  match reg {
    Z => 0
    R1 => 1
    R2 => 2
    R3 => 3
    R4 => 4
    R5 => 5
    SP => 6
    PC => 7
  }
}

impl Decode for ControlOp with decode(op) -> ControlOp? {
  match op {
    0 => Some(ControlOp::Halt)
    1 => Some(ControlOp::Setz)
    2 => Some(ControlOp::Clrz)
    3 => Some(ControlOp::Setc)
    4 => Some(ControlOp::Clrc)
    5 => Some(ControlOp::Restore)
    _ => None
  }
}

impl Encode for ControlOp with encode(op) -> UInt {
  match op {
    Halt => 0
    Setz => 1
    Clrz => 2
    Setc => 3
    Clrc => 4
    Restore => 5
  }
}

impl Encode for AluOp with encode(op) -> UInt {
  match op {
    Add => 0b00000
    Sub => 0b00001
    Adc => 0b00010
    Sbc => 0b00011
    AddIfZero => 0b00100
    SubIfZero => 0b00101
    AdcIfZero => 0b00110
    SbcIfZero => 0b00111
    AddIfNotZero => 0b01000
    SubIfNotZero => 0b01001
    AdcIfNotZero => 0b01010
    SbcIfNotZero => 0b01011
    AddIfCarry => 0b01100
    SubIfCarry => 0b01101
    AdcIfCarry => 0b01110
    SbcIfCarry => 0b01111
    AddIfNotCarry => 0b10000
    SubIfNotCarry => 0b10001
    AdcIfNotCarry => 0b10010
    SbcIfNotCarry => 0b10011
    Inc => 0b10100
    Dec => 0b10101
    And => 0b10110
    Nand => 0b10111
    Or => 0b11000
    Xor => 0b11001
    Shl => 0b11010
    Shr => 0b11011
  }
}

impl Decode for AluOp with decode(op) -> AluOp? {
  match op {
    0b00000 => Some(AluOp::Add)
    0b00001 => Some(AluOp::Sub)
    0b00010 => Some(AluOp::Adc)
    0b00011 => Some(AluOp::Sbc)
    0b00100 => Some(AluOp::AddIfZero)
    0b00101 => Some(AluOp::SubIfZero)
    0b00110 => Some(AluOp::AdcIfZero)
    0b00111 => Some(AluOp::SbcIfZero)
    0b01000 => Some(AluOp::AddIfNotZero)
    0b01001 => Some(AluOp::SubIfNotZero)
    0b01010 => Some(AluOp::AdcIfNotZero)
    0b01011 => Some(AluOp::SbcIfNotZero)
    0b01100 => Some(AluOp::AddIfCarry)
    0b01101 => Some(AluOp::SubIfCarry)
    0b01110 => Some(AluOp::AdcIfCarry)
    0b01111 => Some(AluOp::SbcIfCarry)
    0b10000 => Some(AluOp::AddIfNotCarry)
    0b10001 => Some(AluOp::SubIfNotCarry)
    0b10010 => Some(AluOp::AdcIfNotCarry)
    0b10011 => Some(AluOp::SbcIfNotCarry)
    0b10100 => Some(AluOp::Inc)
    0b10101 => Some(AluOp::Dec)
    0b10110 => Some(AluOp::And)
    0b10111 => Some(AluOp::Nand)
    0b11000 => Some(AluOp::Or)
    0b11001 => Some(AluOp::Xor)
    0b11010 => Some(AluOp::Shl)
    0b11011 => Some(AluOp::Shr)
    _ => None
  }
}

impl Encode for Inst with encode(inst) -> UInt {
  match inst {
    Ctl(op~) => {
      (0b00U << 14) | Encode::encode(op)
    }
    Set(dst~, val~) => {
      (0b01U << 14) | (Encode::encode(dst) << 11) | (val & 0x7ff)
    }
    Mem(dst~, addr~, load~, offset~) => {
      (0b10U << 14) |
      (Encode::encode(dst) << 11) |
      (Encode::encode(addr) << 8) |
      ((if load { 1U } else { 0U }) << 7) |
      (offset & 0x7f)
    }
    Alu(dst~, src1~, src2~, op~) => {
      (0b11U << 14) |
      (Encode::encode(dst) << 11) |
      (Encode::encode(src1) << 8) |
      (Encode::encode(src2) << 5) |
      Encode::encode(op)
    }
  }
}

pub fn encode_inst(inst: Inst) -> UInt {
  Encode::encode(inst)
}
