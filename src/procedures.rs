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
