use crate::asm::Assembler;
use crate::isa::Reg;

// dst -> a // b, a -> a % b
pub fn def_division(asm: &mut Assembler, procedure_name: &str, dst: Reg, a: Reg, b: Reg) {
    asm.label(procedure_name)
        .inline_div(dst, a, b, procedure_name)
        .ret();
}
