use crate::isa::{AluOp, Cond, ControlOp, Inst, Reg, STACK_POINTER_TOP};
use std::collections::HashMap;

pub struct Assembler {
    output: Vec<u16>,
    labels: HashMap<String, usize>,
    unresolved_labels: Vec<(String, usize)>,
}

impl Assembler {
    pub fn new() -> Self {
        Assembler {
            output: Vec::new(),
            labels: HashMap::new(),
            unresolved_labels: Vec::new(),
        }
    }

    fn get_relative_offset(label_addr: usize, inst_addr: usize) -> i8 {
        let offset = label_addr as i32 - inst_addr as i32 - 1;

        assert!(
            offset >= -128 && offset <= 127,
            "get_relative_offset: label is too far away (max 127 instructions)"
        );

        offset as i8
    }

    fn push_inst(&mut self, inst: Inst) {
        self.output.push(inst.into());
    }

    pub fn init_sp(&mut self) -> &mut Self {
        self.setw(Reg::SP, STACK_POINTER_TOP, Reg::TMP)
    }

    pub fn assemble(&self) -> Vec<u16> {
        let mut out = self.output.clone();

        for (label, inst_addr) in &self.unresolved_labels {
            if let Some(&label_addr) = self.labels.get(label) {
                let relative_offset = Self::get_relative_offset(label_addr, *inst_addr);
                out[*inst_addr] |= (relative_offset as u16) & 0x7f;
            } else {
                panic!("unresolved label: {label}");
            }
        }

        out
    }

    pub fn nop(&mut self) -> &mut Self {
        self.set(Reg::Z, 0)
    }

    pub fn ctrl(&mut self, op: ControlOp) -> &mut Self {
        self.push_inst(Inst::Ctl { op });
        self
    }

    pub fn halt(&mut self) -> &mut Self {
        self.ctrl(ControlOp::Halt)
    }

    pub fn setc(&mut self) -> &mut Self {
        self.ctrl(ControlOp::Setc)
    }

    pub fn clrc(&mut self) -> &mut Self {
        self.ctrl(ControlOp::Clrc)
    }

    pub fn setz(&mut self) -> &mut Self {
        self.ctrl(ControlOp::Setz)
    }

    pub fn clrz(&mut self) -> &mut Self {
        self.ctrl(ControlOp::Clrz)
    }

    pub fn set(&mut self, dst: Reg, val: u16) -> &mut Self {
        assert!(
            val <= 0x7ff,
            "set: {val} is too large to fit in 11 bits, use `setw` instead"
        );

        self.push_inst(Inst::Set { dst, val });
        self
    }

    pub fn setw(&mut self, dst: Reg, word: u16, tmp: Reg) -> &mut Self {
        assert!(dst != tmp, "setw: dst == tmp");

        if word <= 0x3ff {
            return self.set(dst, word);
        }

        let high = (word >> 8) & 0xff;
        let low = word & 0xff;

        if low == 0 {
            self.set(dst, high);
            self.set(tmp, 8);
            self.shl(dst, dst, tmp);
            self.or(dst, dst, Reg::Z);
        } else {
            self.set(dst, high);
            self.set(tmp, 8);
            self.shl(dst, dst, tmp);
            self.set(tmp, low);
            self.or(dst, dst, tmp);
        }

        self
    }

    pub fn mov_if(&mut self, dst: Reg, src: Reg, cond: Cond) -> &mut Self {
        self.add_if(dst, src, Reg::Z, cond)
    }

    pub fn mov(&mut self, dst: Reg, src: Reg) -> &mut Self {
        self.mov_if(dst, src, Cond::Always)
    }

    // update the zero and carry flags based on the value of the source register
    pub fn update_flags(&mut self, src: Reg) -> &mut Self {
        self.add(Reg::Z, Reg::Z, src)
    }

    pub fn alu(&mut self, dst: Reg, src1: Reg, src2: Reg, op: AluOp) -> &mut Self {
        self.push_inst(Inst::Alu {
            dst,
            src1,
            src2,
            op,
        });

        self
    }

    pub fn add_if(&mut self, dst: Reg, src1: Reg, src2: Reg, cond: Cond) -> &mut Self {
        let op = match cond {
            Cond::Always => AluOp::Add,
            Cond::IfZero => AluOp::AddIfZero,
            Cond::IfNotZero => AluOp::AddIfNotZero,
            Cond::IfCarry => AluOp::AddIfCarry,
            Cond::IfNotCarry => AluOp::AddIfNotCarry,
        };

        self.alu(dst, src1, src2, op)
    }

    pub fn add(&mut self, dst: Reg, src1: Reg, src2: Reg) -> &mut Self {
        self.add_if(dst, src1, src2, Cond::Always)
    }

    pub fn adc_if(&mut self, dst: Reg, src1: Reg, src2: Reg, cond: Cond) -> &mut Self {
        let op = match cond {
            Cond::Always => AluOp::Adc,
            Cond::IfZero => AluOp::AdcIfZero,
            Cond::IfNotZero => AluOp::AdcIfNotZero,
            Cond::IfCarry => AluOp::AdcIfCarry,
            Cond::IfNotCarry => AluOp::AdcIfNotCarry,
        };

        self.alu(dst, src1, src2, op)
    }

    pub fn adc(&mut self, dst: Reg, src1: Reg, src2: Reg) -> &mut Self {
        self.adc_if(dst, src1, src2, Cond::Always)
    }

    pub fn sbc_if(&mut self, dst: Reg, src1: Reg, src2: Reg, cond: Cond) -> &mut Self {
        let op = match cond {
            Cond::Always => AluOp::Sbc,
            Cond::IfZero => AluOp::SbcIfZero,
            Cond::IfNotZero => AluOp::SbcIfNotZero,
            Cond::IfCarry => AluOp::SbcIfCarry,
            Cond::IfNotCarry => AluOp::SbcIfNotCarry,
        };

        self.alu(dst, src1, src2, op)
    }

    pub fn sbc(&mut self, dst: Reg, src1: Reg, src2: Reg) -> &mut Self {
        self.sbc_if(dst, src1, src2, Cond::Always)
    }

    pub fn sub_if(&mut self, dst: Reg, src1: Reg, src2: Reg, cond: Cond) -> &mut Self {
        let op = match cond {
            Cond::Always => AluOp::Sub,
            Cond::IfZero => AluOp::SubIfZero,
            Cond::IfNotZero => AluOp::SubIfNotZero,
            Cond::IfCarry => AluOp::SubIfCarry,
            Cond::IfNotCarry => AluOp::SubIfNotCarry,
        };

        self.alu(dst, src1, src2, op)
    }

    pub fn sub(&mut self, dst: Reg, src1: Reg, src2: Reg) -> &mut Self {
        self.sub_if(dst, src1, src2, Cond::Always)
    }

    pub fn muli2(&mut self, dst: Reg, src: Reg, n: u16, tmp: Reg) -> &mut Self {
        assert!(dst != src, "muli: dst == src");

        if n == 0 {
            return self.mov(dst, Reg::Z);
        }

        if n.is_power_of_two() {
            let log2 = (n as f32).log2() as u16;
            self.set(tmp, log2);
            return self.shl(dst, src, tmp);
        }

        self.set(dst, 0);

        for bit in (0..16).rev() {
            if (n >> bit) & 1 == 1 {
                if bit == 0 {
                    self.add(dst, dst, src);
                } else {
                    self.set(tmp, bit);
                    self.shl(tmp, src, tmp);
                    self.add(dst, dst, tmp);
                }
            }
        }

        self
    }

    pub fn muli(&mut self, dst: Reg, src: Reg, n: u16) -> &mut Self {
        self.muli2(dst, src, n, Reg::TMP)
    }

    pub fn add32(&mut self, hi1: Reg, lo1: Reg, hi2: Reg, lo2: Reg) -> &mut Self {
        self.add(lo1, lo1, lo2);
        self.adc(hi1, hi1, hi2)
    }

    pub fn sub32(&mut self, hi1: Reg, lo1: Reg, hi2: Reg, lo2: Reg) -> &mut Self {
        self.sub(lo1, lo1, lo2);
        self.sbc(hi1, hi1, hi2)
    }

    // dst -> a // b, a -> a % b
    pub fn inline_div(&mut self, dst: Reg, a: Reg, b: Reg, label: &str) -> &mut Self {
        let end_label = format!("__{label}_end");
        let loop_label = format!("__{label}_loop");

        self.set(dst, 0)
            .cmp(a, b)
            .jmp_if_neg(&end_label)
            .label(&loop_label)
            .sub(a, a, b)
            .cmp(a, b)
            .jmp_if_neg(&end_label)
            .inc(dst)
            .jmp(&loop_label)
            .label(&end_label)
            .inc(dst)
    }

    pub fn and(&mut self, dst: Reg, src1: Reg, src2: Reg) -> &mut Self {
        self.alu(dst, src1, src2, AluOp::And)
    }

    pub fn nand(&mut self, dst: Reg, src1: Reg, src2: Reg) -> &mut Self {
        self.alu(dst, src1, src2, AluOp::Nand)
    }

    pub fn or(&mut self, dst: Reg, src1: Reg, src2: Reg) -> &mut Self {
        self.alu(dst, src1, src2, AluOp::Or)
    }

    pub fn xor(&mut self, dst: Reg, src1: Reg, src2: Reg) -> &mut Self {
        self.alu(dst, src1, src2, AluOp::Xor)
    }

    pub fn shl(&mut self, dst: Reg, src1: Reg, src2: Reg) -> &mut Self {
        self.alu(dst, src1, src2, AluOp::Shl)
    }

    pub fn shr(&mut self, dst: Reg, src1: Reg, src2: Reg) -> &mut Self {
        self.alu(dst, src1, src2, AluOp::Shr)
    }

    pub fn not(&mut self, dst: Reg, src: Reg) -> &mut Self {
        self.alu(dst, src, src, AluOp::Nand)
    }

    pub fn cmp(&mut self, src1: Reg, src2: Reg) -> &mut Self {
        self.sub(Reg::Z, src1, src2)
    }

    pub fn inc(&mut self, dst: Reg) -> &mut Self {
        self.alu(dst, dst, Reg::Z, AluOp::Inc)
    }

    pub fn inc2(&mut self, dst: Reg, src: Reg) -> &mut Self {
        self.alu(dst, src, Reg::Z, AluOp::Inc)
    }

    pub fn dec(&mut self, dst: Reg) -> &mut Self {
        self.alu(dst, dst, Reg::Z, AluOp::Dec)
    }

    pub fn dec2(&mut self, dst: Reg, src: Reg) -> &mut Self {
        self.alu(dst, src, Reg::Z, AluOp::Dec)
    }

    fn jmp_if_rel(&mut self, relative_offset: i8, cond: Cond) -> &mut Self {
        self.set(Reg::TMP, relative_offset.abs() as u16);

        if relative_offset < 0 {
            self.sub_if(Reg::PC, Reg::PC, Reg::TMP, cond)
        } else {
            self.add_if(Reg::PC, Reg::PC, Reg::TMP, cond)
        }
    }

    pub fn jmp_if(&mut self, label: &str, cond: Cond) -> &mut Self {
        let inst_addr = self.output.len();

        if let Some(&label_addr) = self.labels.get(label) {
            let relative_offset = Self::get_relative_offset(label_addr, inst_addr);
            self.jmp_if_rel(relative_offset, cond)
        } else {
            self.unresolved_labels.push((label.to_string(), inst_addr));
            self.jmp_if_rel(0, cond) // placeholder
        }
    }

    pub fn jmp(&mut self, label: &str) -> &mut Self {
        self.jmp_if(label, Cond::Always)
    }

    pub fn jmpz(&mut self, label: &str) -> &mut Self {
        self.jmp_if(label, Cond::IfZero)
    }

    pub fn jmpnz(&mut self, label: &str) -> &mut Self {
        self.jmp_if(label, Cond::IfNotZero)
    }

    pub fn jmpc(&mut self, label: &str) -> &mut Self {
        self.jmp_if(label, Cond::IfCarry)
    }

    pub fn jmpnc(&mut self, label: &str) -> &mut Self {
        self.jmp_if(label, Cond::IfNotCarry)
    }

    pub fn jmp_if_pos(&mut self, label: &str) -> &mut Self {
        self.jmp_if(label, Cond::IfCarry)
    }

    pub fn jmp_if_neg(&mut self, label: &str) -> &mut Self {
        self.jmp_if(label, Cond::IfNotCarry)
    }

    pub fn jump_if_eq(&mut self, label: &str) -> &mut Self {
        self.jmp_if(label, Cond::IfZero)
    }

    pub fn jump_if_ne(&mut self, label: &str) -> &mut Self {
        self.jmp_if(label, Cond::IfNotZero)
    }

    pub fn store(&mut self, src: Reg, addr: Reg, offset: u8) -> &mut Self {
        assert!(offset < 128, "store: offset is too large (max 127)");

        self.push_inst(Inst::Mem {
            dst: src,
            addr,
            load: false,
            offset,
        });

        self
    }

    pub fn load(&mut self, dst: Reg, addr: Reg, offset: u8) -> &mut Self {
        assert!(offset < 128, "load: offset is too large (max 127)");

        // read value
        self.push_inst(Inst::Mem {
            dst,
            addr,
            load: true,
            offset,
        });

        self
    }

    pub fn push(&mut self, val: Reg) -> &mut Self {
        self.store(val, Reg::SP, 0);
        self.inc(Reg::SP)
    }

    pub fn pop(&mut self, dst: Reg) -> &mut Self {
        self.dec(Reg::SP);
        self.load(dst, Reg::SP, 0)
    }

    // return from a procedure call
    pub fn ret(&mut self) -> &mut Self {
        self.pop(Reg::PC)
    }

    pub fn call(&mut self, procedure_label: &str) -> &mut Self {
        // skip the next 5 instructions which are part of the call instruction itself
        self.set(Reg::TMP, 5);
        self.add(Reg::TMP, Reg::TMP, Reg::PC);
        self.push(Reg::TMP);
        self.jmp(procedure_label)
    }

    pub fn label(&mut self, label: &str) -> &mut Self {
        assert!(
            !self.labels.contains_key(label),
            "label {label} already defined"
        );

        self.labels.insert(label.to_string(), self.output.len());
        self
    }
}
