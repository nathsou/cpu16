
pub(all) enum Reg {
  Z; R1; R2; R3; R4; TMP; SP; PC
} derive (Show, Eq)

pub(all) enum ControlOp {
    Halt
    Setz
    Clrz
    Setc
    Clrc
    Show(Reg)
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
  Set(dst~: Reg, val~: UInt16)
  Mem(dst~: Reg, addr~: Reg, load~: Bool, offset~: UInt16)
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
    TMP => 5
    SP => 6
    PC => 7
  }
}

impl Decode for Reg with decode(reg) -> Reg? {
  match reg {
    0 => Some(Reg::Z)
    1 => Some(Reg::R1)
    2 => Some(Reg::R2)
    3 => Some(Reg::R3)
    4 => Some(Reg::R4)
    5 => Some(Reg::TMP)
    6 => Some(Reg::SP)
    7 => Some(Reg::PC)
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
    Show(reg) => (Encode::encode(reg) << 3) | 5
  }
}

impl Decode for ControlOp with decode(op) -> ControlOp? {
  match op {
    0 => Some(ControlOp::Halt)
    1 => Some(ControlOp::Setz)
    2 => Some(ControlOp::Clrz)
    3 => Some(ControlOp::Setc)
    4 => Some(ControlOp::Clrc)
    _ => {
      if (op & 0b111) == 5U {
        let reg = Reg::decode((op >> 3) & 0b111U)
        reg.map(r => ControlOp::Show(r))
      } else {
        None
      }
    }
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

pub impl Encode for Inst with encode(inst) -> UInt {
  match inst {
    Ctl(op~) => {
      (0b00U << 14) | Encode::encode(op)
    }
    Set(dst~, val~) => {
      (0b01U << 14) | (Encode::encode(dst) << 11) | (val.to_uint() & 0x7ff)
    }
    Mem(dst~, addr~, load~, offset~) => {
      (0b10U << 14) |
      (Encode::encode(dst) << 11) |
      (Encode::encode(addr) << 8) |
      ((if load { 1U } else { 0U }) << 7) |
      (offset.to_uint() & 0x7f)
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

pub impl Decode for Inst with decode(word) -> Inst? {
  let op = (word >> 14) & 0b11U

  match op {
    0b00U => {
      let ctl_op = ControlOp::decode(word & 0x3ffU)
      ctl_op.map(op => Inst::Ctl(op~))
    }
    0b01U => {
      let dst = Reg::decode((word >> 11) & 0b111U)
      let val = (word & 0x7ffU).reinterpret_as_int().to_uint16()
      dst.map(dst => Inst::Set(dst~, val~))
    }
    0b10U => {
      let dst = Reg::decode((word >> 11) & 0b111U)
      let addr = Reg::decode((word >> 8) & 0b111U)
      let load = ((word >> 7) & 0b1U) == 1U
      let offset = (word & 0x7fU).reinterpret_as_int().to_uint16()
      
      match (dst, addr) {
        (Some(dst), Some(addr)) => Some(Inst::Mem(dst~, addr~, load~, offset~))
        _ => None
      }
    }
    0b11U => {
      let dst = Reg::decode((word >> 11) & 0b111U)
      let src1 = Reg::decode((word >> 8) & 0b111U)
      let src2 = Reg::decode((word >> 5) & 0b111U)
      let alu_op = AluOp::decode(word & 0b11111U)
      
      match (dst, src1, src2, alu_op) {
        (Some(dst), Some(src1), Some(src2), Some(op)) => Some(Inst::Alu(dst~, src1~, src2~, op~))
        _ => None
      }
    }
    _ => None
  }
}
