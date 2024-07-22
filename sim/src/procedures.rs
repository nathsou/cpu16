use crate::asm::Assembler;
use crate::isa::Reg;

// dst -> a // b, a -> a % b
pub fn def_division(asm: &mut Assembler, procedure_name: &str, dst: Reg, a: Reg, b: Reg) {
    asm.label(procedure_name)
        .inline_div(dst, a, b, procedure_name)
        .ret();
}

pub fn def_is_power_of_two(asm: &mut Assembler, procedure_name: &str, n: Reg) {
    use Reg::*;

    let loop_label = format!("{}_loop", procedure_name);
    let is_not_power_of_two_label = format!("{}_is_not_power_of_two", procedure_name);
    let end_label = format!("{}_end", procedure_name);

    let iter = R3;
    let count = R4;
    assert!(n != iter);
    assert!(n != count);

    // count number of bits set to 1 in n
    asm.label(procedure_name)
        .set(count, 0)
        .set(iter, 0)
        .label(&loop_label)
        .set(TMP, 1)
        .and(TMP, n, TMP)
        .add(count, count, TMP)
        .set(TMP, 1)
        .shr(n, n, TMP)
        .inc(iter)
        .set(TMP, 16)
        .cmp(iter, TMP)
        .jump_if_ne(&loop_label)
        .set(TMP, 1)
        .cmp(count, TMP)
        .jump_if_ne(&is_not_power_of_two_label)
        .set(n, 1)
        .jmp(&end_label)
        .label(&is_not_power_of_two_label)
        .set(n, 0)
        .label(&end_label)
        .ret();
}

// R1: n, R2: str pointer
pub fn def_itoa(asm: &mut Assembler) {
    // void itoa(int num, char* str) {
    //     int powersOf10[] = {10000, 1000, 100, 10, 1};
    //     char digits[] = "0123456789";
    //     int i = 0;
    //     int pos = 0;

    //     if (num == 0) {
    //         str[pos++] = '0';
    //         str[pos] = '\0';
    //         return;
    //     }

    //     for (i = 0; i < 5; i++) {
    //         int power = powersOf10[i];
    //         int count = 0;
    //         while (num >= power) {
    //             num -= power;
    //             count++;
    //         }

    //         if (pos > 0 || count > 0) {
    //             str[pos++] = digits[count];
    //         }
    //     }

    //     str[pos] = '\0';
    // }

    use Reg::*;

    asm.label("itoa");

    // variable addresses in RAM
    let num = 100;
    let str_ptr = 101;
    let powers_of_10 = 102;

    // store the arguments to RAM
    asm.store(R1, Z, num);
    asm.store(R2, Z, str_ptr);

    // powers of 10 LUT
    asm.set(R1, powers_of_10);
    asm.setw(R2, 10_000, TMP);
    asm.store(R2, R1, 0);
    asm.set(R2, 1000);
    asm.store(R2, R1, 1);
    asm.set(R2, 100);
    asm.store(R2, R1, 2);
    asm.set(R2, 10);
    asm.store(R2, R1, 3);
    asm.setw(R2, 1, TMP);
    asm.store(R2, R1, 4);

    asm.load(R1, Z, powers_of_10 as u8);

    // check if num is zero
    asm.load(R1, Z, num);
    asm.cmp(R1, Z);
    asm.jump_if_ne("itoa_not_zero");
    asm.load(R2, Z, str_ptr);
    asm.set(TMP, b'0' as u16);
    asm.store(TMP, R2, 0);
    asm.store(Z, R2, 1); // null terminator
    asm.ret();

    // num is not zero, start conversion
    asm.label("itoa_not_zero");
    asm.set(R1, 0); // i
    asm.set(R2, 0); // pos
    asm.label("itoa_main_loop");
    asm.set(TMP, 5);
    asm.cmp(R1, TMP);
    asm.jump_if_eq("itoa_end_main_loop");
    asm.set(R4, 0); // count
    asm.label("itoa_while_num_ge_power");
    asm.load(R3, R1, powers_of_10 as u8); // power = powersOf10[i]
    asm.load(TMP, Z, num);
    asm.cmp(TMP, R3);
    asm.jmpnc("itoa_end_while_num_ge_power");
    asm.load(TMP, Z, num);
    asm.sub(TMP, TMP, R3);
    asm.store(TMP, Z, num);
    asm.inc(R4);
    asm.jmp("itoa_while_num_ge_power");

    asm.label("itoa_end_while_num_ge_power");
    asm.inc(R1); // i++

    // if (pos > 0 || count > 0) {
    asm.update_flags(R2);
    asm.jmpnz("itoa_append_digit");
    asm.update_flags(R4);
    asm.jmpnz("itoa_append_digit");
    asm.jmp("itoa_main_loop");

    asm.label("itoa_append_digit");
    // str[pos] = digits[count];
    asm.load(R3, Z, str_ptr);
    asm.add(R3, R3, R2); // str_ptr + pos
    asm.set(TMP, 0x30); // 0 ascii
    asm.add(TMP, TMP, R4);
    asm.store(TMP, R3, 0);
    asm.inc(R2); // pos++
    asm.jmp("itoa_main_loop");

    asm.label("itoa_end_main_loop");

    // add null terminator
    asm.load(R1, Z, str_ptr);
    asm.add(R1, R1, R2); // str_ptr + pos
    asm.store(Z, R1, 0);

    asm.ret();
}

// R1: str pointer, R2: first tile index
pub fn def_print(asm: &mut Assembler) {
    use Reg::*;

    let char = 100;

    asm.label("print");
    // R4 = 0xffff (PPU address)
    asm.set(R4, 0);
    asm.dec(R4);

    asm.label("print_loop");
    // check if null terminator
    asm.load(R3, R1, 0);
    asm.store(R3, Z, char);
    asm.cmp(R3, Z);
    asm.jmpz("print_end");

    // write to PPU

    // set tile index
    asm.setw(R3, 0x8000, TMP);
    asm.add(R3, R3, R2);
    asm.store(R3, R4, 0);
    asm.inc(R2);

    // set tile data
    asm.load(R3, Z, char);
    asm.store(R3, R4, 0);
    asm.inc(R1);
    asm.jmp("print_loop");

    asm.label("print_end");
    asm.ret();
}
