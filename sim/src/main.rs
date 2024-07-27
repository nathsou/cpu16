use std::io::Write;

use asm::Assembler;
use isa::Reg;
use procedures::{def_division, def_is_power_of_two, def_itoa, def_print};
use serde::Serialize;
use serde_json::json;
use sim::CPU;

mod asm;
mod isa;
mod procedures;
mod sim;

fn add() -> Vec<u16> {
    use Reg::*;

    Assembler::new()
        .set(R1, 0x23)
        .set(R2, 0x17)
        .add(R1, R1, R2)
        .halt()
        .assemble()
}

fn sub() -> Vec<u16> {
    use Reg::*;

    Assembler::new()
        .set(R1, 0x23)
        .set(R2, 0x17)
        .sub(R1, R1, R2)
        .halt()
        .assemble()
}

fn muli() -> Vec<u16> {
    use Reg::*;

    Assembler::new()
        .set(R2, 0x23)
        .muli(R1, R2, 0x17)
        .halt()
        .assemble()
}

fn xor() -> Vec<u16> {
    use Reg::*;

    Assembler::new()
        .set(R2, 0x23)
        .set(R3, 0x17)
        .xor(R1, R2, R3)
        .halt()
        .assemble()
}

fn dec() -> Vec<u16> {
    use Reg::*;

    Assembler::new().set(R1, 0x23).dec(R1).halt().assemble()
}

fn count() -> Vec<u16> {
    use Reg::*;

    Assembler::new()
        .set(R1, 0xa)
        .set(R2, 0)
        .label("loop")
        .dec(R1)
        .jmpnz("loop")
        .halt()
        .assemble()
}

fn div() -> Vec<u16> {
    use Reg::*;

    let mut asm = Assembler::new();

    asm.init_sp().set(R2, 1621).set(R3, 17).call("div").halt();

    def_division(&mut asm, "div", R1, R2, R3);

    asm.assemble()
}

fn add32() -> Vec<u16> {
    use Reg::*;

    Assembler::new()
        .setw(R1, 0x1234, TMP)
        .setw(R2, 0xbaba, TMP)
        .setw(R3, 0x4321, TMP)
        .setw(R4, 0x5678, TMP)
        .add32(R1, R2, R3, R4)
        .halt()
        .assemble()
}

fn euler1() -> Vec<u16> {
    use Reg::*;

    // ram addresses
    let n = 0;
    let sum_hi = 1;
    let sum_lo = 2;

    let mut asm = Assembler::new();

    asm.init_sp()
        .store(Z, Z, sum_lo)
        .store(Z, Z, sum_hi)
        .setw(TMP, 1000, R1)
        .dec(TMP)
        .store(TMP, Z, n)
        .label("loop")
        .load(R1, Z, n)
        .set(R3, 3)
        .call("div")
        .update_flags(R1)
        .jmpz("is_divisible")
        .load(R1, Z, n)
        .set(R3, 5)
        .call("div")
        .update_flags(R1)
        .jmpz("is_divisible")
        .label("loop_back")
        .load(R1, Z, n)
        .dec(R1)
        .store(R1, Z, n)
        .jmpnz("loop")
        .jmp("end")
        .label("is_divisible")
        .load(R1, Z, n)
        .load(R2, Z, sum_hi)
        .load(R3, Z, sum_lo)
        .add32(R2, R3, Z, R1)
        .store(R2, Z, sum_hi)
        .store(R3, Z, sum_lo)
        .jmp("loop_back")
        .label("end")
        .load(R1, Z, sum_hi)
        .load(R2, Z, sum_lo)
        .halt();

    def_division(&mut asm, "div", R2, R1, R3);

    asm.assemble()
}

fn lab() -> Vec<u16> {
    use Reg::*;

    let mut asm = Assembler::new();

    asm.init_sp()
        .setw(R1, 0xbaba, TMP)
        .set(R2, 0x20)
        .call("itoa")
        .set(R1, 0x20)
        .set(R2, 0)
        .call("print")
        .halt();

    def_itoa(&mut asm);
    def_print(&mut asm);

    asm.assemble()
}

fn call() -> Vec<u16> {
    use Reg::*;

    Assembler::new()
        .jmp("start")
        .label("yo")
        .set(R1, 0x23)
        .ret()
        .label("start")
        .set(R1, 7)
        .call("yo")
        .inc(R1)
        .halt()
        .assemble()
}

fn mem() -> Vec<u16> {
    use Reg::*;

    Assembler::new()
        .set(R1, 0x23)
        .store(R1, Z, 3)
        .set(R1, 0)
        .load(R1, Z, 3)
        .halt()
        .assemble()
}

fn stack() -> Vec<u16> {
    use Reg::*;

    Assembler::new()
        .init_sp()
        .set(R1, 0x23)
        .push(R1)
        .set(R1, 0x11)
        .pop(R1)
        .halt()
        .assemble()
}

fn power_of_two() -> Vec<u16> {
    use Reg::*;

    let mut asm = Assembler::new();

    asm.init_sp()
        .setw(R1, 0x80, TMP)
        .call("is_power_of_two")
        .halt();

    def_is_power_of_two(&mut asm, "is_power_of_two", R1);

    asm.assemble()
}

fn yo_fpga() -> Vec<u16> {
    use Reg::*;

    let mut asm = Assembler::new();

    let message = "Hello, FPGA!";

    asm.init_sp().setw(R2, 0xffff, TMP).setw(R3, 1 << 15, TMP);

    for byte in message.bytes() {
        asm.store(R3, R2, 0);
        asm.set(R1, byte as u16).store(R1, R2, 0);
        asm.inc(R3);
    }

    asm.halt().assemble()
}

fn itoa() -> Vec<u16> {
    use Reg::*;

    let mut asm = Assembler::new();

    asm.init_sp()
        .setw(R1, 0xbaba, TMP) // num
        .set(R2, 0x20) // str_ptr
        .call("itoa")
        .halt();

    def_itoa(&mut asm);

    asm.assemble()
}

#[test]
fn test_add() {
    let mut cpu = CPU::from(&add());

    cpu.run();

    assert_eq!(cpu.regs[Reg::R1 as usize], 0x23 + 0x17);
}

#[test]
fn test_sub() {
    let mut cpu = CPU::from(&sub());

    cpu.run();

    assert_eq!(cpu.regs[Reg::R1 as usize], 0x23 - 0x17);
}

#[test]
fn test_muli() {
    let mut cpu = CPU::from(&muli());

    cpu.run();

    assert_eq!(cpu.regs[Reg::R1 as usize], 0x23 * 0x17);
}

#[test]
fn test_xor() {
    let mut cpu = CPU::from(&xor());

    cpu.run();

    assert_eq!(cpu.regs[Reg::R1 as usize], 0x23 ^ 0x17);
}

#[test]
fn test_dec() {
    let mut cpu = CPU::from(&dec());

    cpu.run();

    assert_eq!(cpu.regs[Reg::R1 as usize], 0x23 - 1);
}

#[test]
fn test_count() {
    let mut cpu = CPU::from(&count());

    cpu.run();

    assert_eq!(cpu.regs[Reg::R1 as usize], 0);
}

#[test]
fn test_div() {
    let mut cpu = CPU::from(&div());

    cpu.run();

    assert_eq!(cpu.regs[Reg::R1 as usize], 1621 / 17);
}

#[test]
fn test_add32() {
    let mut cpu = CPU::from(&add32());

    cpu.run();

    let sum: u32 = 0x1234_baba + 0x4321_5678;
    assert_eq!(cpu.regs[Reg::R1 as usize], (sum >> 16) as u16);
    assert_eq!(cpu.regs[Reg::R2 as usize], (sum & 0xffff) as u16);
}

#[test]
fn test_mem() {
    let mut cpu = CPU::from(&mem());

    cpu.run();

    assert_eq!(cpu.ram[3], 0x23);
}

#[test]
fn test_euler1() {
    let mut cpu = CPU::from(&euler1());

    cpu.run();

    assert_eq!(cpu.regs[Reg::R1 as usize], 0x0003);
    assert_eq!(cpu.regs[Reg::R2 as usize], 0x8ed0);
}

#[test]
fn test_stack() {
    let mut cpu = CPU::from(&stack());

    cpu.run();

    assert_eq!(cpu.regs[Reg::R1 as usize], 0x23);
}

#[test]
fn test_power_of_two() {
    let mut cpu = CPU::from(&power_of_two());

    cpu.run();

    assert_eq!(cpu.regs[Reg::R1 as usize], 1);
}

#[test]
fn test_itoa() {
    let mut cpu = CPU::from(&itoa());

    cpu.run();

    let mut str = String::new();

    for i in 0x20..0x26 {
        str.push(char::from(cpu.ram[i] as u8));
    }

    assert_eq!(str, "47802\0");
}

fn dump_instructions(prog: &[u16]) {
    println!("module ROM (");
    println!("    i_addr: input logic<16>,");
    println!("    o_data: output logic<16>,");
    println!(") {{");
    println!("    always_comb {{");
    println!("        case i_addr {{");

    for (i, &inst) in prog.iter().enumerate() {
        println!("            {i}: o_data = 16'h{inst:04X};");
    }

    println!("            default: o_data = 16'h0000;");
    println!("        }}");
    println!("    }}");
    println!("}}");
}

fn main() {
    let prog = add();

    let disasm = prog
        .iter()
        .map(|&inst| isa::Inst::from(inst))
        .collect::<Vec<_>>();

    for (i, inst) in disasm.iter().enumerate() {
        println!("{:04x}: {}", i, inst);
    }

    let cpu = CPU::from(&prog);

    let mut output_file =
        std::fs::File::create("trace.jsonl").expect("failed to create output file");

    for state in cpu {
        let state_json = serde_json::to_string(&state).expect("failed to serialize state");
        output_file
            .write_all(state_json.as_bytes())
            .expect("failed to write to output file");

        output_file
            .write_all(b"\n")
            .expect("failed to write to output file");
    }

    // println!("{}", cpu);

    // for i in 0x20..0x26 {
    //     println!("{:04x}: {:04x}", i, cpu.ram[i]);
    // }

    dump_instructions(&prog);
}
