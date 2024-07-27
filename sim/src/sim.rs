use crate::isa::{AluOp, Cond, ControlOp, Inst, Reg, STACK_POINTER_TOP};
use serde::Serialize;

pub struct CPU {
    pub regs: [u16; 8],
    pub halted: bool,
    pub carry: bool,
    pub zero: bool,
    pub rom: [u16; 0x10000],
    pub ram: [u16; 0x10000],
    next_pc: u16,
}

#[derive(Serialize, Debug)]
pub struct CPUState {
    r1: u16,
    r2: u16,
    r3: u16,
    r4: u16,
    tmp: u16,
    sp: u16,
    pc: u16,
    zero: bool,
    carry: bool,
    halt: bool,
}

impl CPU {
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

    pub fn from(prog: &[u16]) -> Self {
        let mut rom = [0; 0x10000];
        rom[..prog.len()].copy_from_slice(prog);

        Self::new(rom)
    }

    pub fn set_reg(&mut self, reg: Reg, val: u16) {
        match reg {
            Reg::Z => {}
            Reg::PC => self.next_pc = val,
            _ => self.regs[reg as usize] = val,
        }
    }

    pub fn run(&mut self) {
        while !self.halted {
            self.step();
        }
    }

    pub fn run_with_fuel(&mut self, fuel: usize, verbose: bool) -> Option<usize> {
        for i in 0..fuel {
            if self.halted {
                return Some(i);
            }

            if verbose {
                println!("{self}");
            }

            self.step();
        }

        None
    }

    pub fn run_verbose(&mut self) {
        while !self.halted {
            println!("{self}");
            self.step();
        }
    }

    pub fn step(&mut self) {
        let pc = self.regs[Reg::PC as usize];
        let inst = Inst::from(self.rom[pc as usize]);
        self.next_pc = pc.wrapping_add(1);

        match inst {
            Inst::Ctl { op } => {
                match op {
                    ControlOp::Halt => self.halted = true,
                    ControlOp::Setz => self.zero = true,
                    ControlOp::Clrz => self.zero = false,
                    ControlOp::Setc => self.carry = true,
                    ControlOp::Clrc => self.carry = false,
                };
            }
            Inst::Set { dst, val } => {
                self.set_reg(dst, val);
            }
            Inst::Mem {
                dst,
                addr,
                load,
                offset,
            } => {
                let addr = self.regs[addr as usize].wrapping_add(offset as u16);

                if load {
                    self.set_reg(dst, self.ram[addr as usize]);
                } else {
                    self.ram[addr as usize] = self.regs[dst as usize];
                }
            }
            Inst::Alu {
                dst,
                src1,
                src2,
                op,
            } => {
                let a = self.regs[src1 as usize];
                let b = self.regs[src2 as usize];
                let mut cond_met = true;
                let mut new_carry = self.carry;

                let out = match op {
                    AluOp::And => a & b,
                    AluOp::Nand => !(a & b),
                    AluOp::Or => a | b,
                    AluOp::Xor => a ^ b,
                    AluOp::Shl => a << (b & 0xf),
                    AluOp::Shr => a >> (b & 0xf),
                    _ => {
                        let op_u16 = op as u16;
                        let is_sub = op_u16 & 1 == 1;
                        let include_carry = (op_u16 & 0b11) == 0b10 || (op_u16 & 0b11) == 0b11; // all adc and sbc operations
                        let force_carry = (op_u16 & 0b11) == 1 || op == AluOp::Inc; // all sub operations or inc
                        let condition = Cond::from((op_u16 & 0b11100) >> 2);
                        let carry_in =
                            op != AluOp::Dec && (force_carry || (include_carry && self.carry));

                        cond_met = match condition {
                            Cond::Always => true,
                            Cond::IfZero => self.zero,
                            Cond::IfNotZero => !self.zero,
                            Cond::IfCarry => self.carry,
                            Cond::IfNotCarry => !self.carry,
                        };

                        let b = if is_sub { !b } else { b };
                        let (sum1, carry_out1) = a.overflowing_add(b);
                        let (sum2, carry_out2) = sum1.overflowing_add(carry_in as u16);
                        new_carry = carry_out1 || carry_out2;

                        sum2
                    }
                };

                if cond_met {
                    self.carry = new_carry;
                    self.zero = out == 0;
                    self.set_reg(dst, out);
                }
            }
        }

        self.regs[Reg::PC as usize] = self.next_pc;
    }

    pub fn get_state(&self) -> CPUState {
        CPUState {
            r1: self.regs[Reg::R1 as usize],
            r2: self.regs[Reg::R2 as usize],
            r3: self.regs[Reg::R3 as usize],
            r4: self.regs[Reg::R4 as usize],
            tmp: self.regs[Reg::TMP as usize],
            sp: self.regs[Reg::SP as usize],
            pc: self.regs[Reg::PC as usize],
            zero: self.zero,
            carry: self.carry,
            halt: self.halted,
        }
    }
}

impl Iterator for CPU {
    type Item = CPUState;

    fn next(&mut self) -> Option<Self::Item> {
        if self.halted {
            None
        } else {
            self.step();
            Some(self.get_state())
        }
    }
}

impl std::fmt::Display for CPU {
    // r1: 0003, r2: 0000, r3: 0000, r4: 0000, tmp: 0000, sp: 0000, pc: 0001, flags: (c: 0, z: 0), set r1 3
    fn fmt(&self, f: &mut std::fmt::Formatter) -> std::fmt::Result {
        for (i, reg) in self.regs.iter().skip(1).enumerate() {
            write!(f, "  {}: {:04x}", Reg::from((i + 1) as u16), reg)?;
        }

        let inst = self.rom[self.regs[Reg::PC as usize] as usize];
        let inst = Inst::from(inst);

        write!(
            f,
            "  flags: (c: {}, z: {})",
            self.carry as u8, self.zero as u8
        )?;

        write!(f, " {inst}")?;

        let stack_ptr = self.regs[Reg::SP as usize];

        if stack_ptr > STACK_POINTER_TOP {
            let stack = &self.ram[(STACK_POINTER_TOP as usize)..stack_ptr as usize];
            let fmt = stack
                .iter()
                .map(|&val| format!("{:04x}", val))
                .collect::<Vec<_>>()
                .join(", ");

            write!(f, ", stack: [{}]", fmt)?;
        }

        Ok(())
    }
}
