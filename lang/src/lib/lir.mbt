// Lower Intermidiate Representation
// Raw instructions with variables instead of registers (before register allocation)

pub enum Loc {
    Reg(Reg)
    Var(IRVarId)
    Label(TACLabel)
} derive (Show)

pub fn variables(self: Loc) -> Array[IRVarId] {
    match self {
        Loc::Var(v) => [v]
        _ => []
    }
}

pub fn substitute_var(self: Loc, reg_mapping: Map[IRVarId, Int]) -> Loc {
    match self {
        Loc::Var(v) => {
            match reg_mapping[v] {
                Some(reg) => Loc::Reg(match reg {
                    0 => Reg::R1
                    1 => Reg::R2
                    2 => Reg::R3
                    3 => Reg::R4
                    4 => Reg::R5
                    _ => abort("invalid register")
                })
                None => Loc::Var(v)
            }
        }
        _ => self
    }
}

pub enum LIRCond {
    IfZero; IfNotZero; IfCarry; IfNotCarry
} derive (Show)

pub enum LIR {
    Ctl(~op: ControlOp)
    Set(~dst: Loc, ~val: UInt)
    Mem(~dst: Loc, ~addr: Loc, ~load: Bool, ~offset: UInt)
    Alu(~dst: Loc, ~src1: Loc, ~src2: Loc, ~op: AluOp)
    Jmp(~dst: Loc, ~cond: Option[LIRCond])
    Label(TACLabel)
} derive (Show)

pub fn variables(self: LIR) -> Array[IRVarId] {
    let vars = match self {
        LIR::Ctl(_) => []
        LIR::Set(~dst, ~val=_) => dst.variables()
        LIR::Mem(~dst, ~addr, ~load=_, ~offset=_) => dst.variables() + addr.variables()
        LIR::Alu(~dst, ~src1, ~src2, ~op=_) => dst.variables() + src1.variables() + src2.variables()
        LIR::Jmp(~dst, ~cond=_) => dst.variables()
        LIR::Label(_) => []
    }

    let set = Map::new()

    for i = 0; i < vars.length(); i = i + 1 {
        set[vars[i]] = ()
    }

    set.keys().collect()
}

pub struct LIRBuilder {
    mut insts: Array[LIR]
    mut next_var_id: IRVarId
}

pub type! LIRBuilderError String derive (Show)

fn raisep(msg: String) -> Unit!LIRBuilderError {
    println(msg)
    raise LIRBuilderError(msg)
}

pub fn LIRBuilder::from(ir_builder: IRBuilder) -> LIRBuilder {
    {
        insts: [],
        next_var_id: ir_builder.next_var_id,
    }
}

fn next_var_id(self: LIRBuilder) -> IRVarId {
    let var_id = self.next_var_id
    self.next_var_id += 1U
    var_id
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
                raisep!("TODO: implement large constant lowering")
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
            raisep!("TODO: implement Mul")
        }
        IR::Div(..) => {
            raisep!("TODO: implement Div")
        }
        IR::Mod(..) => {
            raisep!("TODO: implement Mod")
        }
        IR::Not(..) => {
            raisep!("TODO: implement Not")
        }
        IR::And(..) => {
            raisep!("TODO: implement And")
        }
        IR::Or(..) => {
            raisep!("TODO: implement Or")
        }
        IR::Xor(..) => {
            raisep!("TODO: implement Xor")
        }
        IR::Jump(~label) => {
            self.emit(LIR::Jmp(~dst=Loc::Label(label), ~cond=None))
        }
        IR::JumpIf(~label, ~cond, ~lhs, ~rhs) => {
            match cond {
                TACCond::Equ => {
                    self.emit(LIR::Alu(~dst=Loc::Reg(Reg::Z), ~src1=Loc::Var(lhs), ~src2=Loc::Var(rhs), ~op=AluOp::Sub))
                    self.emit(LIR::Jmp(~dst=Loc::Label(label), ~cond=Some(LIRCond::IfZero)))
                }
                TACCond::Neq => {
                    self.emit(LIR::Alu(~dst=Loc::Reg(Reg::Z), ~src1=Loc::Var(lhs), ~src2=Loc::Var(rhs), ~op=AluOp::Sub))
                    self.emit(LIR::Jmp(~dst=Loc::Label(label), ~cond=Some(LIRCond::IfNotZero)))
                }
                _ => {
                    raisep!("TODO: implement other conditions")
                }
            }
        }
        IR::Label(label) => {
            self.emit(LIR::Label(label))
        }
    }
}

// TODO: implement https://wikiwand.com/en/articles/Live_variable_analysis
pub fn liveness_intervals(self: LIRBuilder) -> Map[IRVarId, (Int, Int)] {
    let intervals: Map[IRVarId, (Int, Int)] = Map::new()

    for i = 0; i < self.insts.length(); i = i + 1 {
        let vars = self.insts[i].variables()

        for j = 0; j < vars.length(); j = j + 1 {
            let var = vars[j]

            match intervals[var] {
                Some((start, _)) => {
                    intervals[var] = (start, i)
                }
                None => {
                    intervals[var] = (i, i)
                }
            }
        }
    }

    intervals
}

type! RegAllocationError String derive (Show)

fn remove_associative_array[K: Eq, V](array: Array[(K, V)], key: K) -> Unit {
    match array.find_index(fn (x) { x.0 == key }) {
        Some(idx) => {
            array.swap(idx, array.length() - 1)
            let _ = array.pop_exn()
        }
        None => ()
    }
}

fn insert_associative_array[K: Eq, V](array: Array[(K, V)], ~key: K, ~value: V, ~lss: (V, V) -> Bool) -> Unit {
    match array.find_index(fn (x) { lss(x.1, value) }) {
        Some(idx) => {
            array.insert(idx, (key, value))
        }
        None => {
            array.push((key, value))
        }
    }
}

pub fn allocate_registers(self: LIRBuilder, ~regs_count: Int) -> Map[IRVarId, Int] {
    let intervals = self.liveness_intervals()
    let reg_alloc: Map[IRVarId, Int] = Map::new()
    let active: Array[(Int, (Int, Int))] = []
    let free_regs: @queue.T[Int] = @queue.new()

    for i = 0; i < regs_count; i = i + 1 {
        free_regs.push(i)
    }

    fn expire_old_intervals(interval_end: Int) -> Unit {
        active.eachi(fn (j, entry) {
            let (reg, interval) = entry
            let (_, end) = interval

            if interval_end >= end {
                remove_associative_array(active, j)
                free_regs.push(reg)
            }
        })
    }

    intervals.each(fn (var_id, interval) {
        let (_, end) = interval
        expire_old_intervals(end)

        if active.length() >= regs_count {
            abort("TODO: implement SpillAtInterval")
        } else {
            let reg = free_regs.pop_exn()
            reg_alloc[var_id] = reg
            insert_associative_array(
                active,
                ~key=reg,
                ~value=interval,
                ~lss=fn (x, y) { x.1 < y.1 }
            )
        }
    })

    reg_alloc
}

pub fn remove_labels(self: LIRBuilder) -> Unit {
    let insts = []
    let label_pos: Map[TACLabel, Int] = Map::new()

    for idx, inst in self.insts {
        match inst {
            LIR::Label(label) => {
                label_pos[label] = idx - label_pos.size()
            }
            _ => ()
        }
    }

    let mut additional_insts = 0

    // replace labels
    for idx, inst in self.insts {
        match inst {
            LIR::Jmp(~dst=Loc::Label(label), ~cond) => {
                let pos = label_pos[label].unwrap() + additional_insts
                let delta = pos - idx

                let op = if delta >= 0 {
                    match cond {
                        Some(LIRCond::IfZero) => AluOp::AddIfZero
                        Some(LIRCond::IfNotZero) => AluOp::AddIfNotZero
                        Some(LIRCond::IfCarry) => AluOp::AddIfCarry
                        Some(LIRCond::IfNotCarry) => AluOp::AddIfNotCarry
                        None => AluOp::Add
                    }
                } else {
                    match cond {
                        Some(LIRCond::IfZero) => AluOp::SubIfZero
                        Some(LIRCond::IfNotZero) => AluOp::SubIfNotZero
                        Some(LIRCond::IfCarry) => AluOp::SubIfCarry
                        Some(LIRCond::IfNotCarry) => AluOp::SubIfNotCarry
                        None => AluOp::Sub
                    }
                }

                if delta.abs() < 4096 { // 11 bits
                    let offset_id = self.next_var_id()
                    insts.push(LIR::Set(~dst=Loc::Var(offset_id), ~val=delta.abs().to_uint()))
                    insts.push(LIR::Alu(
                        ~dst=Loc::Reg(Reg::PC),
                        ~src1=Loc::Reg(Reg::PC),
                        ~src2=Loc::Var(offset_id),
                        ~op,
                    ))

                    additional_insts += 1
                } else {
                    abort("TODO: implement large jump offset")
                }
            }
            Label(_) => ()
            _ => {
                insts.push(inst)
            }
        }
    }

    self.insts = insts
}

pub fn allocate(self: LIRBuilder, ~regs_count: Int = 5) -> Unit {
    let reg_mapping = self.allocate_registers(~regs_count)

    for i = 0; i < self.insts.length(); i = i + 1 {
        self.insts[i] = match self.insts[i] {
            LIR::Ctl(~op) => LIR::Ctl(~op=op)
            LIR::Set(~dst, ~val) => LIR::Set(~dst=dst.substitute_var(reg_mapping), ~val=val)
            LIR::Mem(~dst, ~addr, ~load, ~offset) => LIR::Mem(
                ~dst=dst.substitute_var(reg_mapping),
                ~addr=addr.substitute_var(reg_mapping),
                ~load=load,
                ~offset=offset,
            )
            LIR::Alu(~dst, ~src1, ~src2, ~op) => LIR::Alu(
                ~dst=dst.substitute_var(reg_mapping),
                ~src1=src1.substitute_var(reg_mapping),
                ~src2=src2.substitute_var(reg_mapping),
                ~op=op,
            )
            LIR::Jmp(~dst, ~cond) => LIR::Jmp(
                ~dst=dst.substitute_var(reg_mapping),
                ~cond=cond,
            )
            LIR::Label(_) => self.insts[i]
        }
    }
}

type! InstLoweringError {
    UnexpectedJmp
    UnexpectedLabel
    InvalidLoc(Loc)
} derive (Show)

pub fn lower_lir(self: LIRBuilder) -> Array[Inst]!InstLoweringError {
    let insts = []

    fn get_reg(loc: Loc) -> Reg!InstLoweringError {
        match loc {
            Loc::Reg(reg) => reg
            _ => raise InstLoweringError::InvalidLoc(loc)
        }
    }

    for i = 0; i < self.insts.length(); i = i + 1 {
        let inst = self.insts[i]

        match inst {
            LIR::Ctl(~op) => {
                insts.push(Inst::Ctl(~op=op))
            }
            LIR::Set(~dst, ~val) => {
                insts.push(Inst::Set(~dst=get_reg!(dst), ~val=val))
            }
            LIR::Mem(~dst, ~addr, ~load, ~offset) => {
                insts.push(Inst::Mem(
                    ~dst=get_reg!(dst),
                    ~addr=get_reg!(addr),
                    ~load=load,
                    ~offset=offset,
                ))
            }
            LIR::Alu(~dst, ~src1, ~src2, ~op) => {
                insts.push(Inst::Alu(
                    ~dst=get_reg!(dst),
                    ~src1=get_reg!(src1),
                    ~src2=get_reg!(src2),
                    ~op=op,
                ))
            }
            LIR::Jmp(..) => {
                raise InstLoweringError::UnexpectedJmp
            }
            LIR::Label(_) => {
                raise InstLoweringError::UnexpectedLabel
            }
        }
    }

    insts
}
