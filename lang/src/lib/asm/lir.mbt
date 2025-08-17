// Lower Intermediate Representation
// Raw instructions with variables instead of registers (before register allocation) and labels

pub enum Loc {
    Reg(Reg)
    Var(VarId)
    Mem(offset~: Int)
    Label(LabelId)
} derive (Show)

pub fn variables(self: Loc) -> Array[VarId] {
    match self {
        Loc::Var(v) => [v]
        _ => []
    }
}

struct VariableAllocation {
    reg_alloc: Map[VarId, Int]
    mem_alloc: Map[VarId, Int]
}

pub fn substitute_var(self: Loc, alloc: VariableAllocation) -> Loc {
    match self {
        Loc::Var(v) => {
            match alloc.reg_alloc.get(v) {
                Some(reg) => Loc::Reg(match reg {
                    0 => Reg::R1
                    1 => Reg::R2
                    2 => Reg::R3
                    3 => Reg::R4
                    4 => Reg::TMP
                    _ => abort("invalid register")
                })
                None => match alloc.mem_alloc.get(v) {
                    Some(mem) => Loc::Mem(offset=mem)
                    None => Loc::Var(v)
                }
            }
        }
        _ => self
    }
}

pub enum LIRCond {
    Always; IfZero; IfNotZero; IfCarry; IfNotCarry
} derive (Show)

pub fn LIRCond::from(cond: UInt) -> LIRCond {
    match cond {
        1 => IfZero
        2 => IfNotZero
        3 => IfCarry
        4 => IfNotCarry
        _ => Always
    }
}

pub enum LIR {
    Ctl(op~: ControlOp)
    Set(dst~: Loc, val~: UInt16)
    Mem(dst~: Loc, addr~: Loc, load~: Bool, offset~: UInt16)
    Alu(dst~: Loc, src1~: Loc, src2~: Loc, op~: AluOp)
    Jmp(dst~: Loc, cond~: LIRCond)
    Label(LabelId)
} derive (Show)

pub fn LIR::variables(self: LIR) -> Array[VarId] {
    let vars = match self {
        LIR::Ctl(_) => []
        LIR::Set(dst~, val=_) => dst.variables()
        LIR::Mem(dst~, addr~, load=_, offset=_) => dst.variables() + addr.variables()
        LIR::Alu(dst~, src1~, src2~, op=_) => dst.variables() + src1.variables() + src2.variables()
        LIR::Jmp(dst~, cond=_) => dst.variables()
        LIR::Label(_) => []
    }

    let unique = Set::from_array(vars).to_array()
    unique
}

pub struct LIRBuilder {
    mut insts: Array[LIR]
    mut next_var_id: VarId
}

suberror LIRBuilderError String derive (Show)

pub fn LIRBuilder::new(next_var_id: VarId) -> LIRBuilder {
    {
        insts: [],
        next_var_id,
    }
}

pub fn LIRBuilder::from(insts: Array[LIR], next_var_id: VarId) -> LIRBuilder {
    {
        insts,
        next_var_id,
    }
}

fn next_var_id(self: LIRBuilder) -> VarId {
    let var_id = self.next_var_id
    // Increment without relying on Add trait for IRVarId
    self.next_var_id = self.next_var_id.inner() + 1U
    var_id
}

fn LIRBuilder::emit(self: LIRBuilder, inst: LIR) -> Unit {
    self.insts.push(inst)
}

fn emit_move(self: LIRBuilder, dst: Loc, src: Loc) -> Unit {
    self.emit(LIR::Alu(dst=dst, src1=src, src2=Loc::Reg(Reg::Z), op=AluOp::Add))
}

pub fn lower_ir(self: LIRBuilder, ir: IR) -> Unit raise LIRBuilderError {
    match ir {
        IR::Set(dst~, val~) => {
            let val_uint = val.reinterpret_as_uint()

            if val_uint >= 4096 {
                raise LIRBuilderError("TODO: implement large constant lowering")
            }

            self.emit(LIR::Set(dst=Loc::Var(dst), val=val_uint.reinterpret_as_int().to_uint16()))
        }
        IR::Load(dst~, src~) => {
            self.emit(LIR::Mem(dst=Loc::Var(dst), addr=Loc::Var(src), load=true, offset=0))
        }
        IR::Store(dst~, src~) => {
            self.emit(LIR::Mem(dst=Loc::Var(dst), addr=Loc::Var(src), load=false, offset=0))
        }
        IR::Move(dst~, src~) => {
            self.emit_move(Loc::Var(dst), Loc::Var(src))
        }
        IR::Add(dst~, src1~, src2~) => {
            self.emit(LIR::Alu(dst=Loc::Var(dst), src1=Loc::Var(src1), src2=Loc::Var(src2), op=AluOp::Add))
        }
        IR::Sub(dst~, src1~, src2~) => {
            self.emit(LIR::Alu(dst=Loc::Var(dst), src1=Loc::Var(src1), src2=Loc::Var(src2), op=AluOp::Sub))
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
        IR::Jump(label~) => {
            self.emit(LIR::Jmp(dst=Loc::Label(label), cond=Always))
        }
        IR::JumpIf(label~, cond~, lhs~, rhs~) => {
            match cond {
                JumpCond::Equ => {
                    self.emit(LIR::Alu(dst=Loc::Reg(Reg::Z), src1=Loc::Var(lhs), src2=Loc::Var(rhs), op=AluOp::Sub))
                    self.emit(LIR::Jmp(dst=Loc::Label(label), cond=IfZero))
                }
                JumpCond::Neq => {
                    self.emit(LIR::Alu(dst=Loc::Reg(Reg::Z), src1=Loc::Var(lhs), src2=Loc::Var(rhs), op=AluOp::Sub))
                    self.emit(LIR::Jmp(dst=Loc::Label(label), cond=IfNotZero))
                }
                JumpCond::Lss => {
                    self.emit(LIR::Alu(dst=Loc::Reg(Reg::Z), src1=Loc::Var(lhs), src2=Loc::Var(rhs), op=AluOp::Sub))
                    self.emit(LIR::Jmp(dst=Loc::Label(label), cond=IfNotCarry))
                }
                JumpCond::Gtr => {
                    self.emit(LIR::Alu(dst=Loc::Reg(Reg::Z), src1=Loc::Var(lhs), src2=Loc::Var(rhs), op=AluOp::Sub))
                    self.emit(LIR::Jmp(dst=Loc::Label(label), cond=IfCarry))
                }
                JumpCond::Geq => {
                    self.emit(LIR::Alu(dst=Loc::Reg(Reg::Z), src1=Loc::Var(rhs), src2=Loc::Var(lhs), op=AluOp::Sub))
                    self.emit(LIR::Jmp(dst=Loc::Label(label), cond=IfNotCarry))
                }
                JumpCond::Leq => {
                    // reverse lhs and rhs
                    self.emit(LIR::Alu(dst=Loc::Reg(Reg::Z), src1=Loc::Var(rhs), src2=Loc::Var(lhs), op=AluOp::Sub))
                    self.emit(LIR::Jmp(dst=Loc::Label(label), cond=IfCarry))
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
    let intervals: Map[VarId, (Int, Int)] = Map::new()

    for i = 0; i < self.insts.length(); i = i + 1 {
        let vars = self.insts[i].variables()

        for j = 0; j < vars.length(); j = j + 1 {
            let v = vars[j]

            match intervals.get(v) {
                Some((start, _)) => {
                    intervals[v] = (start, i)
                }
                None => {
                    intervals[v] = (i, i)
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

priv struct SortedArray[T] {
    values: Array[T]
}

fn[T] SortedArray::new() -> SortedArray[T] {
    { values: [] }
}

fn[T: Eq] remove(self: SortedArray[T], value: T) -> Unit {
    match self.values.search_by(x => x == value) {
        Some(idx) => {
            self.values.swap(idx, self.values.length() - 1)
            let _ = self.values.unsafe_pop()
        }
        None => ()
    }
}

fn[T: Compare] insert(self: SortedArray[T], value: T) -> Unit {
    match self.values.search_by(x => x < value) {
        Some(idx) => {
            self.values.insert(idx, value)
        }
        None => {
            self.values.push(value)
        }
    }
}

struct LivenessInterval {
    var_id: VarId
    start: Int
    end: Int
} derive (Eq)

impl Compare for LivenessInterval with compare(a: LivenessInterval, b: LivenessInterval) -> Int {
    Compare::compare(a.end, b.end)
}

// Linear scan register allocation
// TODO: Graph coloring register allocation
pub fn allocate_registers(self: LIRBuilder, regs_count~: Int) -> VariableAllocation {
    let intervals = self.liveness_intervals()
    let reg_alloc: Map[VarId, Int] = Map::new()
    let mem_alloc: Map[VarId, Int] = Map::new()
    let active: SortedArray[LivenessInterval] = SortedArray::new()
    let free_regs: Array[Int] = []

    for i = regs_count - 1; i >= 0; i = i - 1 {
        free_regs.push(i)
    }

    fn expire_old_intervals(expired_interval: LivenessInterval) -> Unit {
        for i = 0; i < active.values.length(); i = i + 1 {
            let interval = active.values[i]
            if interval.end < expired_interval.start {
                active.remove(interval)
                free_regs.push(reg_alloc.get(interval.var_id).unwrap())
            }
        }
    }

    fn spill_at_interval(interval: LivenessInterval) -> Unit {
        let spill_candidate = active.values.last().unwrap()
        let new_mem_loc = mem_alloc.size()
        
        if spill_candidate.end > interval.end {
            reg_alloc[interval.var_id] = reg_alloc.get(spill_candidate.var_id).unwrap() 
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
            let reg = free_regs.unsafe_pop()
            reg_alloc[interval.var_id] = reg
            active.insert(interval)
        }
    }

    { reg_alloc, mem_alloc }
}

pub fn remove_labels(self: LIRBuilder, automatic_jump_temp_reg~: Bool) -> Unit raise InstLoweringError {
    let without_jumps: Array[LIR] = []
    let jump_offsets_to_fix: Map[Int, LabelId] = Map::new()
    let visited_labels: Map[LabelId, Unit] = Map::new()

    for inst in self.insts {
        match inst {
            LIR::Jmp(dst=Loc::Label(label), cond~) => {
                let jmp_offset_loc = if automatic_jump_temp_reg { Var(self.next_var_id()) } else { Reg(TMP) }
                let is_backward_jump = visited_labels.contains(label)
                let op = if is_backward_jump {
                    match cond {
                        Always => AluOp::Sub
                        IfZero => AluOp::SubIfZero
                        IfNotZero => AluOp::SubIfNotZero
                        IfCarry => AluOp::SubIfCarry
                        IfNotCarry => AluOp::SubIfNotCarry
                    }
                } else {
                    match cond {
                        Always => AluOp::Add
                        IfZero => AluOp::AddIfZero
                        IfNotZero => AluOp::AddIfNotZero
                        IfCarry => AluOp::AddIfCarry
                        IfNotCarry => AluOp::AddIfNotCarry
                    }
                }

                jump_offsets_to_fix[without_jumps.length()] = label
                without_jumps.push(LIR::Set(dst=jmp_offset_loc, val=0)) // placeholder
                without_jumps.push(LIR::Alu(
                    dst=Loc::Reg(Reg::PC),
                    src1=Loc::Reg(Reg::PC),
                    src2=jmp_offset_loc,
                    op~,
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

    // Compute relative offset of a label
    fn compute_relative_offset(index: Int, label: LabelId) -> UInt raise InstLoweringError {
        let max_offset = @cmp.maximum(index, without_jumps.length() - index)

        let mut delta_forward = 0U
        let mut delta_backward = 0U

        for i = 0; i < max_offset; i = i + 1 {
            if index + i < without_jumps.length() {
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

        raise InstLoweringError::MissingLabel(label)
    }

    // Fix jump offsets
    for index, label in jump_offsets_to_fix {
        let offset = compute_relative_offset(index, label)
        let inst = without_jumps[index]

        if offset > 0xFFFF {
            raise InstLoweringError::UnexpectedJmp
        }

        match inst {
            LIR::Set(dst~, val=_) => {
                without_jumps[index] = LIR::Set(dst~, val=offset.reinterpret_as_int().to_uint16())
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

pub fn allocate(self: LIRBuilder, regs_count~: Int = 5) -> Unit {
    let alloc = self.allocate_registers(regs_count~)

    for i = 0; i < self.insts.length(); i = i + 1 {
        self.insts[i] = match self.insts[i] {
            LIR::Ctl(op~) => LIR::Ctl(op~)
            LIR::Set(dst~, val~) => LIR::Set(dst=dst.substitute_var(alloc), val=val)
            LIR::Mem(dst~, addr~, load~, offset~) => LIR::Mem(
                dst=dst.substitute_var(alloc),
                addr=addr.substitute_var(alloc),
                load~,
                offset~,
            )
            LIR::Alu(dst~, src1~, src2~, op~) => LIR::Alu(
                dst=dst.substitute_var(alloc),
                src1=src1.substitute_var(alloc),
                src2=src2.substitute_var(alloc),
                op~,
            )
            LIR::Jmp(dst~, cond~) => LIR::Jmp(
                dst=dst.substitute_var(alloc),
                cond~,
            )
            LIR::Label(_) => self.insts[i]
        }
    }
}

suberror InstLoweringError {
    UnexpectedJmp
    UnexpectedLabel
    InvalidLoc(Loc)
    MissingLabel(LabelId)
} derive (Show)

pub fn lower_lir(self: LIRBuilder) -> Array[Inst] raise InstLoweringError {
    let insts = []

    fn get_reg(loc: Loc) -> Reg raise InstLoweringError {
        match loc {
            Loc::Reg(reg) => reg
            Loc::Mem(offset=_) => {
                println("TODO: handle variables in memory")
                abort("memory access")
            }
            _ => raise InstLoweringError::InvalidLoc(loc)
        }
    }

    for inst in self.insts {
        match inst {
            LIR::Ctl(op~) => {
                insts.push(Inst::Ctl(op=op))
            }
            LIR::Set(dst~, val~) => {
                insts.push(Inst::Set(dst=get_reg(dst), val~))
            }
            LIR::Mem(dst~, addr~, load~, offset~) => {
                insts.push(Inst::Mem(
                    dst=get_reg(dst),
                    addr=get_reg(addr),
                    load~,
                    offset~,
                ))
            }
            LIR::Alu(dst~, src1~, src2~, op~) => {
                insts.push(Inst::Alu(
                    dst=get_reg(dst),
                    src1=get_reg(src1),
                    src2=get_reg(src2),
                    op~,
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

    // halt
    insts.push(Ctl(op=Halt))

    insts
}

pub fn LIRBuilder::lower(insts: Array[LIR], next_var_id~: VarId, automatic_jump_temp_reg~: Bool) -> Array[Inst] raise InstLoweringError {
    let builder = LIRBuilder::from(insts, next_var_id)
    builder
        ..remove_labels(automatic_jump_temp_reg~)
        ..allocate()

    builder.lower_lir()
}
