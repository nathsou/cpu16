
pub struct CPU {
    regs: FixedArray[UInt16]
    mut halted: Bool
    mut carry: Bool
    mut zero: Bool
    mem: FixedArray[UInt16]
    mut next_pc: UInt16
}

pub fn CPU::new(mem: FixedArray[UInt16], start_addr: UInt16) -> CPU {
    {
        regs: {
            let regs: FixedArray[UInt16] = FixedArray::make(8, 0)
            regs[7] = start_addr
            regs
        },
        halted: false,
        carry: false,
        zero: false,
        mem,
        next_pc: start_addr,
    }
}

pub fn CPU::from(prog: Bytes, start_addr: UInt16) -> CPU {
    let mem: FixedArray[UInt16] = FixedArray::make(0x10000, 0)
    let mut mem_index = 0

    for i = 0; i < prog.length(); i = i + 2 {
        let word: UInt16 = (prog[i].to_uint16() | (prog[i + 1].to_uint16() << 8))
        mem[mem_index + start_addr.to_int()] = word
        mem_index += 1
    }

    CPU::new(mem, start_addr)
}

fn write_reg(self: CPU, reg: @asm.Reg, value: UInt16) -> Unit {
    match reg {
        Z => ()
        R1 => self.regs[1] = value
        R2 => self.regs[2] = value
        R3 => self.regs[3] = value
        R4 => self.regs[4] = value
        TMP => self.regs[5] = value
        SP => self.regs[6] = value
        PC => self.next_pc = value
    }
}

fn read_reg(self: CPU, reg: @asm.Reg) -> UInt16 {
    match reg {
        Z => self.regs[0]
        R1 => self.regs[1]
        R2 => self.regs[2]
        R3 => self.regs[3]
        R4 => self.regs[4]
        TMP => self.regs[5]
        SP => self.regs[6]
        PC => self.regs[7]
    }
}

fn bitwise_not(n: UInt16) -> UInt16 {
    n ^ 0xFFFF
}

pub fn step(self: CPU) -> Unit {
    let pc = self.regs[7]
    let inst_uint = self.mem[pc.to_int()].to_uint()
    let inst = @asm.Inst::decode(inst_uint).unwrap()
    self.next_pc = pc + 1

    match inst {
        Ctl(op~) => match op {
            Halt => self.halted = true
            Setz => self.zero = true
            Clrz => self.zero = false
            Setc => self.carry = true
            Clrc => self.carry = false
        }
        Set(dst~, val~) => self.write_reg(dst, val)
        Mem(dst~, addr~, load~, offset~) => {
            let addr_with_offset = (self.read_reg(addr) + offset).to_int()

            if load {
                self.write_reg(dst, self.mem[addr_with_offset])
            } else {
                self.mem[addr_with_offset] = self.read_reg(dst)
            }
        }
        Alu(dst~, src1~, src2~, op~) => {
            let a = self.read_reg(src1)
            let b = self.read_reg(src2)
            let mut cond_met = true
            let mut new_carry = self.carry

            let out = match op {
                And => a & b
                Nand => bitwise_not(a & b)
                Or => a | b
                Xor => a ^ b
                Shl => a << (b.to_int() & 0xF)
                Shr => a >> (b.to_int() & 0xF)
                _ => {
                    let op_uint = inst_uint & 0b11111U
                    let is_sub = (op_uint & 1) == 1
                    let include_carry = (op_uint & 0b11) == 0b10 || (op_uint & 0b11) == 0b11 // all adc and sbc operations
                    let force_carry = ((op_uint & 0b11) == 1) || (op == Inc) // all sub operations or inc
                    let condition = @asm.LIRCond::from((op_uint & 0b11100) >> 2)
                    let carry_in = op != Dec && (force_carry || (include_carry && self.carry))

                    cond_met = match condition {
                        Always => true
                        IfZero => self.zero
                        IfNotZero => !self.zero
                        IfCarry => self.carry
                        IfNotCarry => !self.carry
                    }

                    let b = if is_sub { bitwise_not(b) } else { b}
                    let sum = a.to_uint() + b.to_uint() + carry_in.to_uint()
                    new_carry = (sum & 0x10000) != 0

                    (sum & 0xFFFF).reinterpret_as_int().to_uint16()
                }
            }

            if cond_met {
                self.carry = new_carry
                self.zero = out == 0
                self.write_reg(dst, out)
            }
        }
    }

    self.regs[7] = self.next_pc
}

pub fn show_nat(n: UInt16, base~: UInt16, digits~: Int? = None) -> String {
    let builder = StringBuilder::new()

    if n == 0 {
        builder.write_char('0')
    } else {
        let mut n = n

        while n > 0 {
            let div = n / base
            let digit = n - (div * base)
            n = div
            builder.write_char(match digit {
                0 => '0'; 1 => '1'; 2 => '2'; 3 => '3'; 4 => '4'; 5 => '5'; 6 => '6'; 7 => '7'; 8 => '8'; 9 => '9'
                10 => 'a'; 11 => 'b'; 12 => 'c'; 13 => 'd'; 14 => 'e'; 15 => 'f'
                _ => '?'
            })
        }
    }

    let res = builder.to_string().rev()
    
    match digits {
        Some(digits) => res.pad_start(digits, '0')
        None => res
    }
}

pub impl Show for CPU with output(self, logger) {
    logger.write_string("r1: \{show_nat(self.regs[1], base=16, digits=Some(4))} ")
    logger.write_string("r2: \{show_nat(self.regs[2], base=16, digits=Some(4))} ")
    logger.write_string("r3: \{show_nat(self.regs[3], base=16, digits=Some(4))} ")
    logger.write_string("r4: \{show_nat(self.regs[4], base=16, digits=Some(4))} ")
    logger.write_string("r5: \{show_nat(self.regs[5], base=16, digits=Some(4))} ")
    logger.write_string("sp: \{show_nat(self.regs[6], base=16, digits=Some(4))} ")
    logger.write_string("pc: \{show_nat(self.regs[7], base=16, digits=Some(4))} ")

    logger.write_string("h: \{self.halted.to_uint()} ")
    logger.write_string("c: \{self.carry.to_uint()} ")
    logger.write_string("z: \{self.zero.to_uint()} ")

    let inst = self.mem[self.regs[7].to_int()]
    let inst = @asm.Inst::decode(inst.to_uint()).unwrap()
    logger.write_string("\{inst.to_string()}")
}
