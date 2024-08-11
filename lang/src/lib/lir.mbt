// Lower Intermidiate Representation
// Raw instructions with variables instead of registers (before register allocation)

pub enum Loc {
    Reg(Reg)
    Var(IRVarId)
    Label(Int)
}

pub enum LIRCond {
    IfZero; IfNotZero; IfCarry; IfNotCarry
}

pub enum LIR {
    Ctl(~op: ControlOp)
    Set(~dst: Loc, ~val: UInt)
    Mem(~dst: Loc, ~addr: Loc, ~load: Bool, ~offset: UInt)
    Alu(~dst: Loc, ~src1: Loc, ~src2: Loc, ~op: AluOp)
    Jmp(~dst: Loc, ~cond: Option[LIRCond])
    Label(~bb: Int)
}

pub struct LIRBuilder {
    insts: Array[LIR]
}

pub type! LIRBuilderError String derive (Show)

pub fn LIRBuilder::new() -> LIRBuilder {
    {
        insts: [],
    }
}

fn emit(self: LIRBuilder, inst: LIR) -> Unit {
    self.insts.push(inst)
}

fn emit_move(self: LIRBuilder, dst: Loc, src: Loc) -> Unit {
    self.emit(LIR::Alu(~dst=dst, ~src1=src, ~src2=Loc::Reg(Reg::Z), ~op=AluOp::Add))
}

pub fn lower_ir(self: LIRBuilder, ir: IR) -> Unit!LIRBuilderError {
    match ir {
        IR::Set(~dst, ~val) => {
            let val_uint = val.to_uint()

            if val_uint > 0x7F {
                raise LIRBuilderError("TODO: implement large constant lowering")
            }

            self.emit(LIR::Set(~dst=Loc::Var(dst), ~val=val_uint))
        }
        IR::Load(~dst, ~src) => {
            self.emit(LIR::Mem(~dst=Loc::Var(dst), ~addr=Loc::Var(src), ~load=true, ~offset=0U))
        }
        IR::Store(~dst, ~src) => {
            self.emit(LIR::Mem(~dst=Loc::Var(dst), ~addr=Loc::Var(src), ~load=false, ~offset=0U))
        }
        IR::Move(~dst, ~src) => {
            self.emit_move(Loc::Var(dst), Loc::Var(src))
        }
        IR::Add(~dst, ~src1, ~src2) => {
            self.emit(LIR::Alu(~dst=Loc::Var(dst), ~src1=Loc::Var(src1), ~src2=Loc::Var(src2), ~op=AluOp::Add))
        }
        IR::Sub(~dst, ~src1, ~src2) => {
            self.emit(LIR::Alu(~dst=Loc::Var(dst), ~src1=Loc::Var(src1), ~src2=Loc::Var(src2), ~op=AluOp::Sub))
        }
        IR::Mul(..) => {
            raise LIRBuilderError("TODO: implement Mul")
        }
        IR::Div(..) => {
            raise LIRBuilderError("TODO: implement Div")
        }
        IR::Mod(..) => {
            raise LIRBuilderError("TODO: implement Mod")
        }
        IR::Not(..) => {
            raise LIRBuilderError("TODO: implement Not")
        }
        IR::And(..) => {
            raise LIRBuilderError("TODO: implement And")
        }
        IR::Or(..) => {
            raise LIRBuilderError("TODO: implement Or")
        }
        IR::Xor(..) => {
            raise LIRBuilderError("TODO: implement Xor")
        }
        IR::Jump(~label_bb) => {
            self.emit(LIR::Jmp(~dst=Loc::Label(label_bb), ~cond=None))
        }
        IR::JumpIf(~label_bb, ~cond, ~lhs, ~rhs) => {
            match cond {
                TACCond::Equ => {
                    self.emit(LIR::Alu(~dst=Loc::Var(lhs), ~src1=Loc::Var(lhs), ~src2=Loc::Var(rhs), ~op=AluOp::Sub))
                    self.emit(LIR::Jmp(~dst=Loc::Label(label_bb), ~cond=Some(LIRCond::IfZero)))
                }
                TACCond::Neq => {
                    self.emit(LIR::Alu(~dst=Loc::Var(lhs), ~src1=Loc::Var(lhs), ~src2=Loc::Var(rhs), ~op=AluOp::Sub))
                    self.emit(LIR::Jmp(~dst=Loc::Label(label_bb), ~cond=Some(LIRCond::IfNotZero)))
                }
                _ => {
                    raise LIRBuilderError("TODO: implement other conditions")
                }
            }
        }
        IR::Label(~bb) => {
            self.emit(LIR::Label(~bb=bb))
        }
    }
}
