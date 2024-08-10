
pub struct Codegen {
    insts: Array[Inst]
    env: Map[String, Reg]
}

type! CodegenError String derive (Show)

fn emit(self: Codegen, inst: Inst) -> Unit {
    self.insts.push(inst)
}

// primitive instructions
fn emit_ctl(self: Codegen, op: ControlOp) -> Unit {
    self.emit(Inst::Ctl(~op))
}
fn emit_set(self: Codegen, dst: Reg, val: UInt) -> Unit!CodegenError {
    if val > 0x7ff {
        raise CodegenError("set: value too large")
    }

    self.emit(Inst::Set(~dst, ~val))
}

fn emit_mem(self: Codegen, dst: Reg, addr: Reg, load: Bool, offset: UInt) -> Unit {
    self.emit(Inst::Mem(~dst, ~addr, ~load, ~offset))
}

fn emit_alu(self: Codegen, dst: Reg, src1: Reg, src2: Reg, op: AluOp) -> Unit {
    self.emit(Inst::Alu(~dst, ~src1, ~src2, ~op))
}
