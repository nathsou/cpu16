
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Reg {
    Z = 0,
    R1,
    R2,
    R3,
    R4,
    TMP,
    SP,
    PC,
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

struct Cpu {
    regs: [u16; 8],
    halted: bool,
    carry: bool,
    zero: bool,
    rom: [u16; 0x10000],
    ram: [u16; 0x10000],
    next_pc: u16,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum AluOp {
    Add = 0b000,
    Adc = 0b001,
    Sbc = 0b010,
    And = 0b011,
    Or = 0b100,
    Xor = 0b101,
    Shl = 0b110,
    Shr = 0b111,
}

impl From<u16> for AluOp {
    fn from(val: u16) -> Self {
        match val {
            0b000 => AluOp::Add,
            0b001 => AluOp::Adc,
            0b010 => AluOp::Sbc,
            0b011 => AluOp::And,
            0b100 => AluOp::Or,
            0b101 => AluOp::Xor,
            0b110 => AluOp::Shl,
            0b111 => AluOp::Shr,
            _ => panic!("Invalid ALU operation"),
        }
    }
}

enum Cond {
    Always = 0b00,
    IfZeroSet = 0b01,
    IfCarrySet = 0b10,
    IfCarryNotSet = 0b11,
}

impl From<u16> for Cond {
    fn from(val: u16) -> Self {
        match val {
            0b00 => Cond::Always,
            0b01 => Cond::IfZeroSet,
            0b10 => Cond::IfCarrySet,
            0b11 => Cond::IfCarryNotSet,
            _ => panic!("Invalid condition"),
        }
    }
}

// instructions:
// ctrl flags                  [{00} <halt: 1> <carry: 1> <zero: 1>] 
// set dst val: reg[dst] = val [{01} <dst: 3> <val: 11>]
// load/store dst addr offset  [{10} <dst: 3> <addr: 3> <load/store: 1> <offset: 7>]
// alu dst src1 src2 op cond   [{11} <dst: 3> <src1: 3> <src2: 3> <op: 3> <cond: 2>]

enum Inst {
    Ctl{halt: bool, carry: bool, zero: bool},
    Set{dst: Reg, val: u16},
    Mem{dst: Reg, addr: Reg, load: bool, offset: u8},
    Alu{dst: Reg, src1: Reg, src2: Reg, op: AluOp, cond: Cond},
}

fn bit(val: u16, i: u8) -> bool {
    val & (1 << i) != 0
}

impl Cpu {
    pub fn new(rom: [u16; 0x10000]) -> Self {
        Self {
            regs: [0; 8],
            halted: false,
            carry: false,
            zero: false,
            rom,
            ram: [0; 0x10000],
            next_pc: 0,
        }
    }

    pub fn set_reg(&mut self, reg: Reg, val: u16) {
        match reg {
            Reg::Z => {},
            Reg::PC => self.next_pc = val,
            _ => self.regs[reg as usize] = val,
        }
    }

    pub fn step(&mut self) {
        let pc = self.regs[Reg::PC as usize];
        let inst = self.rom[pc as usize];
        let op = inst >> 14;
        let dst = Reg::from((inst >> 11) & 0b111);
        self.next_pc = pc.wrapping_add(1);

        match op {
            0b00 => {
                let halt = bit(inst, 13);
                let carry = bit(inst, 12);
                let zero = bit(inst, 11);

                self.halted = halt;
                self.carry = carry;
                self.zero = zero;
            },
            0b01 => {
                let val = inst & 0x7ff;
                self.set_reg(dst, val);
            },
            0b10 => {
                let addr = (inst >> 8) & 0b111;
                let load = bit(inst, 7);
                let offset = inst & 0x7f;
                let addr = self.regs[addr as usize].wrapping_add(offset);

                if load {
                    self.set_reg(dst, self.ram[addr as usize]);
                } else {
                    self.ram[addr as usize] = self.regs[dst as usize];
                }
            },
            0b11 => {
                let src1 = (inst >> 8) & 0b111;
                let src2 = (inst >> 5) & 0b111;
                let op = AluOp::from((inst >> 2) & 0b111);
                let cond = Cond::from(inst & 0b11);

                let a = self.regs[src1 as usize];
                let b = self.regs[src2 as usize];
                let res = match op {
                    AluOp::And => a & b,
                    AluOp::Or => a | b,
                    AluOp::Xor => a ^ b,
                    AluOp::Shl => a << b,
                    AluOp::Shr => a >> b,
                    _ => {
                        let carry_in = match op {
                            AluOp::Adc => self.carry,
                            AluOp::Sbc => !self.carry,
                            _ => false,
                        } as u16;

                        let b = if op == AluOp::Sbc { !b } else { b };
                        let (sum1, carry_out1) = a.overflowing_add(b);
                        let (sum2, carry_out2) = sum1.overflowing_add(carry_in);

                        self.carry = carry_out1 || carry_out2;
                        self.zero = sum2 == 0;

                        sum2
                    },
                };

                let cond_met = match cond {
                    Cond::Always => true,
                    Cond::IfZeroSet => self.zero,
                    Cond::IfCarrySet => self.carry,
                    Cond::IfCarryNotSet => !self.carry,
                };

                if cond_met {
                    self.set_reg(dst, res);
                }
            },
            _ => panic!("Invalid instruction"),
        }

        self.regs[Reg::PC as usize] = self.next_pc;
    }
}

fn main() {
    let a = 0b10101010u8;
    let b = 0b11001100u8;
    let sum = a.wrapping_add(b);
    let xor = a ^ b;

    println!("add: {sum:0>8b}");
    println!("xor: {xor:0>8b}");
}
