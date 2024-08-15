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

            if val_uint >= 4096 {
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
pub fn liveness_intervals(self: LIRBuilder) -> Array[LivenessInterval] {
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

    let liveness_intervals: Array[LivenessInterval] = []

    for var_id, interval in intervals {
        liveness_intervals.push({ var_id, start: interval.0, end: interval.1 })
    }

    liveness_intervals
}

type! RegAllocationError String derive (Show)

struct SortedArray[T] {
    values: Array[T]
    lss: (T, T) -> Bool
}

fn SortedArray::new[T](lss: (T, T) -> Bool) -> SortedArray[T] {
    { values: [], lss }
}

fn remove[T: Eq](self: SortedArray[T], value: T) -> Unit {
    match self.values.find_index(fn (x) { x == value }) {
        Some(idx) => {
            self.values.swap(idx, self.values.length() - 1)
            let _ = self.values.pop_exn()
        }
        None => ()
    }
}

fn insert[T: Eq](self: SortedArray[T], value: T) -> Unit {
    match self.values.find_index(fn (x) { (self.lss)(x, value) }) {
        Some(idx) => {
            self.values.insert(idx, value)
        }
        None => {
            self.values.push(value)
        }
    }
}

struct LivenessInterval {
    var_id: IRVarId
    start: Int
    end: Int
} derive (Eq)

// Linear scan register allocation
// TODO: Graph coloring register allocation
pub fn allocate_registers(self: LIRBuilder, ~regs_count: Int) -> Map[IRVarId, Int] {
    let intervals = self.liveness_intervals()
    let reg_alloc: Map[IRVarId, Int] = Map::new()
    let mem_alloc: Map[IRVarId, Int] = Map::new()
    let active: SortedArray[LivenessInterval] = SortedArray::new(fn (a, b) { a.end < b.end })
    let free_regs: Array[Int] = []

    for i = regs_count - 1; i >= 0; i = i - 1 {
        free_regs.push(i)
    }

    fn expire_old_intervals(expired_interval: LivenessInterval) -> Unit {
        for i = 0; i < active.values.length(); i = i + 1 {
            let interval = active.values[i]
            if interval.end < expired_interval.start {
                active.remove(interval)
                free_regs.push(reg_alloc[interval.var_id].unwrap())
            }
        }
    }

    fn spill_at_interval(interval: LivenessInterval) -> Unit {
        let spill_candidate = active.values.last().unwrap()
        let new_mem_loc = mem_alloc.size()
        
        if spill_candidate.end > interval.end {
            reg_alloc[interval.var_id] = reg_alloc[spill_candidate.var_id].unwrap() 
            mem_alloc[spill_candidate.var_id] = new_mem_loc
            active.remove(spill_candidate)
        } else {
            mem_alloc[interval.var_id] = new_mem_loc
        }
    }

    let intervals_sorted_by_start = intervals.copy()
    intervals_sorted_by_start.sort_by(fn (a, b) { a.start - b.start })

    for interval in intervals_sorted_by_start {
        expire_old_intervals(interval)

        if active.values.length() >= regs_count {
            spill_at_interval(interval)
        } else {
            let reg = free_regs.pop_exn()
            reg_alloc[interval.var_id] = reg
            active.insert(interval)
        }
    }

    reg_alloc
}

pub fn remove_labels(self: LIRBuilder) -> Unit {
    let without_jumps: Array[LIR] = []
    let jump_offsets_to_fix: Map[Int, TACLabel] = Map::new()
    let visited_labels: Map[TACLabel, Unit] = Map::new()

    for inst in self.insts {
        match inst {
            LIR::Jmp(~dst=Loc::Label(label), ~cond) => {
                let jmp_offset_var_id = self.next_var_id()
                let is_backward_jump = visited_labels.contains(label)
                let op = if is_backward_jump {
                    match cond {
                        Some(LIRCond::IfZero) => AluOp::SubIfZero
                        Some(LIRCond::IfNotZero) => AluOp::SubIfNotZero
                        Some(LIRCond::IfCarry) => AluOp::SubIfCarry
                        Some(LIRCond::IfNotCarry) => AluOp::SubIfNotCarry
                        None => AluOp::Sub
                    }
                } else {
                    match cond {
                        Some(LIRCond::IfZero) => AluOp::AddIfZero
                        Some(LIRCond::IfNotZero) => AluOp::AddIfNotZero
                        Some(LIRCond::IfCarry) => AluOp::AddIfCarry
                        Some(LIRCond::IfNotCarry) => AluOp::AddIfNotCarry
                        None => AluOp::Add
                    }
                }

                without_jumps.push(LIR::Set(~dst=Loc::Var(jmp_offset_var_id), ~val=0U)) // placeholder
                jump_offsets_to_fix[without_jumps.length()] = label
                without_jumps.push(LIR::Alu(
                    ~dst=Loc::Reg(Reg::PC),
                    ~src1=Loc::Reg(Reg::PC),
                    ~src2=Loc::Var(jmp_offset_var_id),
                    ~op,
                ))
            }
            LIR::Label(label) => {
                visited_labels[label] = ()
                without_jumps.push(inst)
            }
            _ => {
                without_jumps.push(inst)
            }
        }
    }

    fn max(a: Int, b: Int) -> Int {
        if a > b { a } else { b }
    }

    // Compute relative offset of a label
    fn compute_relative_offset(index: Int, label: TACLabel) -> UInt {
        let max_offset = max(index, without_jumps.length() - index)

        let mut delta_forward = 0U
        let mut delta_backward = 0U

        for i = 0; i < max_offset; i = i + 1 {
            if index + 1 < without_jumps.length() {
                let inst_forward = without_jumps[index + i]

                match inst_forward {
                    LIR::Label(l) => {
                        if l == label {
                            return delta_forward
                        }
                    }
                    _ => {
                        // Skip labels
                        delta_forward += 1
                    }
                }
            }

            if index - i >= 0 {
                let inst_backward = without_jumps[index - i]

                match inst_backward {
                    LIR::Label(l) => {
                        if l == label {
                            return delta_backward
                        }
                    }
                    _ => {
                        // Skip labels
                        delta_backward += 1
                    }
                }
            }
        }

        abort("label not found")
    }

    // Fix jump offsets
    for index, label in jump_offsets_to_fix {
        let offset = compute_relative_offset(index, label)
        let inst = without_jumps[index - 1]

        match inst {
            LIR::Set(~dst=Loc::Var(var_id), ~val=_) => {
                without_jumps[index - 1] = LIR::Set(~dst=Loc::Var(var_id), ~val=offset)
            }
            _ => {
                abort("unexpected instruction during jump offset fixing")
            }
        }
    }

    // Remove labels
    let without_labels: Array[LIR] = []

    for inst in without_jumps {
        match inst {
            LIR::Label(_) => ()
            _ => without_labels.push(inst)
        }
    }

    self.insts = without_labels
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
