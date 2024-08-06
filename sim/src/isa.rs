#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Reg {
    Z = 0,
    R1,
    R2,
    R3,
    R4,
    TMP,
    SP,
    PC,
}

pub const STACK_POINTER_TOP: u16 = 0x7f00;

impl std::fmt::Display for Reg {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let name = match self {
            Reg::Z => "z",
            Reg::R1 => "r1",
            Reg::R2 => "r2",
            Reg::R3 => "r3",
            Reg::R4 => "r4",
            Reg::TMP => "tmp",
            Reg::SP => "sp",
            Reg::PC => "pc",
        };

        write!(f, "{}", name)
    }
}

impl From<u16> for Reg {
    fn from(val: u16) -> Self {
        match val {
            0 => Reg::Z,
            1 => Reg::R1,
            2 => Reg::R2,
            3 => Reg::R3,
            4 => Reg::R4,
            5 => Reg::TMP,
            6 => Reg::SP,
            7 => Reg::PC,
            _ => panic!("Invalid register"),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Cond {
    Always = 0b000,
    IfZero = 0b001,
    IfNotZero = 0b010,
    IfCarry = 0b011,
    IfNotCarry = 0b100,
}

impl From<u16> for Cond {
    fn from(val: u16) -> Self {
        match val {
            0b001 => Cond::IfZero,
            0b010 => Cond::IfNotZero,
            0b011 => Cond::IfCarry,
            0b100 => Cond::IfNotCarry,
            _ => Cond::Always,
        }
    }
}

impl std::fmt::Display for Cond {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let name = match self {
            Cond::Always => "",
            Cond::IfZero => "z",
            Cond::IfNotZero => "nz",
            Cond::IfCarry => "c",
            Cond::IfNotCarry => "nc",
        };

        write!(f, "{}", name)
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AluOp {
    Add = 0b000_00,
    Sub = 0b000_01,
    Adc = 0b000_10,
    Sbc = 0b000_11,

    AddIfZero = 0b001_00,
    SubIfZero = 0b001_01,
    AdcIfZero = 0b001_10,
    SbcIfZero = 0b001_11,

    AddIfNotZero = 0b010_00,
    SubIfNotZero = 0b010_01,
    AdcIfNotZero = 0b010_10,
    SbcIfNotZero = 0b010_11,

    AddIfCarry = 0b011_00,
    SubIfCarry = 0b011_01,
    AdcIfCarry = 0b011_10,
    SbcIfCarry = 0b011_11,

    AddIfNotCarry = 0b100_00,
    SubIfNotCarry = 0b100_01,
    AdcIfNotCarry = 0b100_10,
    SbcIfNotCarry = 0b100_11,

    Inc = 0b101_00,
    Dec = 0b101_01,

    And,
    Nand,
    Or,
    Xor,
    Shl,
    Shr,
}

impl From<u16> for AluOp {
    fn from(val: u16) -> Self {
        match val {
            0 => AluOp::Add,
            1 => AluOp::Sub,
            2 => AluOp::Adc,
            3 => AluOp::Sbc,
            4 => AluOp::AddIfZero,
            5 => AluOp::SubIfZero,
            6 => AluOp::AdcIfZero,
            7 => AluOp::SbcIfZero,
            8 => AluOp::AddIfNotZero,
            9 => AluOp::SubIfNotZero,
            10 => AluOp::AdcIfNotZero,
            11 => AluOp::SbcIfNotZero,
            12 => AluOp::AddIfCarry,
            13 => AluOp::SubIfCarry,
            14 => AluOp::AdcIfCarry,
            15 => AluOp::SbcIfCarry,
            16 => AluOp::AddIfNotCarry,
            17 => AluOp::SubIfNotCarry,
            18 => AluOp::AdcIfNotCarry,
            19 => AluOp::SbcIfNotCarry,
            20 => AluOp::Inc,
            21 => AluOp::Dec,
            22 => AluOp::And,
            23 => AluOp::Nand,
            24 => AluOp::Or,
            25 => AluOp::Xor,
            26 => AluOp::Shl,
            27 => AluOp::Shr,
            _ => panic!("Invalid ALU operation"),
        }
    }
}

impl std::fmt::Display for AluOp {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let name = match self {
            AluOp::Add => "add",
            AluOp::Sub => "sub",
            AluOp::Adc => "adc",
            AluOp::Sbc => "sbc",
            AluOp::AddIfZero => "addz",
            AluOp::SubIfZero => "subz",
            AluOp::AdcIfZero => "adcz",
            AluOp::SbcIfZero => "sbcz",
            AluOp::AddIfNotZero => "addnz",
            AluOp::SubIfNotZero => "subnz",
            AluOp::AdcIfNotZero => "adcnz",
            AluOp::SbcIfNotZero => "sbcnz",
            AluOp::AddIfCarry => "addc",
            AluOp::SubIfCarry => "subc",
            AluOp::AdcIfCarry => "adcc",
            AluOp::SbcIfCarry => "sbcc",
            AluOp::AddIfNotCarry => "addnc",
            AluOp::SubIfNotCarry => "subnc",
            AluOp::AdcIfNotCarry => "adcnc",
            AluOp::SbcIfNotCarry => "sbcnc",
            AluOp::Inc => "inc",
            AluOp::Dec => "dec",
            AluOp::And => "and",
            AluOp::Nand => "nand",
            AluOp::Or => "or",
            AluOp::Xor => "xor",
            AluOp::Shl => "shl",
            AluOp::Shr => "shr",
        };

        write!(f, "{name}")
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ControlOp {
    Halt = 0,
    Setz,
    Clrz,
    Setc,
    Clrc,
    Restore,
}

impl From<u16> for ControlOp {
    fn from(val: u16) -> Self {
        match val {
            0 => ControlOp::Halt,
            1 => ControlOp::Setz,
            2 => ControlOp::Clrz,
            3 => ControlOp::Setc,
            4 => ControlOp::Clrc,
            _ => panic!("Invalid control operation"),
        }
    }
}

impl std::fmt::Display for ControlOp {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        let name = match self {
            ControlOp::Halt => "halt",
            ControlOp::Setz => "setz",
            ControlOp::Clrz => "clrz",
            ControlOp::Setc => "setc",
            ControlOp::Clrc => "clrc",
            ControlOp::Restore => "restore",
        };

        write!(f, "{}", name)
    }
}

// instructions:
// ctrl flags                  [{00} <padding: 11> <sel: 3>]
// set dst val: reg[dst] = val [{01} <dst: 3> <val: 11>]
// load/store dst addr offset  [{10} <dst: 3> <addr: 3> <load/store: 1> <offset: 7>]
// alu dst src1 src2 op cond   [{11} <dst: 3> <src1: 3> <src2: 3> <op: 5>]

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Inst {
    Ctl {
        op: ControlOp,
    },
    Set {
        dst: Reg,
        val: u16,
    },
    Mem {
        dst: Reg,
        addr: Reg,
        load: bool,
        offset: u8,
    },
    Alu {
        dst: Reg,
        src1: Reg,
        src2: Reg,
        op: AluOp,
    },
}

fn bit(val: u16, pos: u16) -> bool {
    (val & (1 << pos)) != 0
}

impl From<u16> for Inst {
    fn from(val: u16) -> Self {
        match val >> 14 {
            0b00 => Inst::Ctl {
                op: ControlOp::from(val & 0b111),
            },
            0b01 => Inst::Set {
                dst: Reg::from((val >> 11) & 0b111),
                val: val & 0x7ff,
            },
            0b10 => Inst::Mem {
                dst: Reg::from((val >> 11) & 0b111),
                addr: Reg::from((val >> 8) & 0b111),
                load: bit(val, 7),
                offset: (val & 0b1111111) as u8,
            },
            0b11 => Inst::Alu {
                dst: Reg::from((val >> 11) & 0b111),
                src1: Reg::from((val >> 8) & 0b111),
                src2: Reg::from((val >> 5) & 0b111),
                op: AluOp::from(val & 0b11111),
            },
            _ => panic!("Invalid instruction"),
        }
    }
}

impl Into<u16> for Inst {
    fn into(self) -> u16 {
        match self {
            Inst::Ctl { op } => {
                let mut inst = 0b00 << 14;
                inst |= match op {
                    ControlOp::Halt => 0,
                    ControlOp::Setz => 1,
                    ControlOp::Clrz => 2,
                    ControlOp::Setc => 3,
                    ControlOp::Clrc => 4,
                    ControlOp::Restore => 5,
                };

                inst
            }
            Inst::Set { dst, val } => {
                let mut inst = 0b01 << 14;
                inst |= (dst as u16) << 11;
                inst |= val & 0x7ff;
                inst
            }
            Inst::Mem {
                dst,
                addr,
                load,
                offset,
            } => {
                let mut inst = 0b10 << 14;
                inst |= (dst as u16) << 11;
                inst |= (addr as u16) << 8;
                inst |= (load as u16) << 7;
                inst |= (offset & 0x7f) as u16;
                inst
            }
            Inst::Alu {
                dst,
                src1,
                src2,
                op,
            } => {
                let mut inst = 0b11 << 14;
                inst |= (dst as u16) << 11;
                inst |= (src1 as u16) << 8;
                inst |= (src2 as u16) << 5;
                inst |= op as u16;

                inst
            }
        }
    }
}

impl std::fmt::Display for Inst {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Inst::Ctl { op } => write!(f, "{op}"),
            Inst::Set { dst, val } => write!(f, "set {dst} {val:04x}"),
            Inst::Mem {
                dst,
                addr,
                load,
                offset,
            } => write!(
                f,
                "{} {}, {} + {:04x}",
                if *load { "load" } else { "store" },
                dst,
                addr,
                offset
            ),
            Inst::Alu {
                dst,
                src1,
                src2,
                op,
            } => {
                write!(f, "{} {}, {}, {}", op, dst, src1, src2)
            }
        }
    }
}
