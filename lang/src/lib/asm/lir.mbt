// Lower Intermediate Representation
// Raw instructions with variables instead of registers (before register allocation) and labels

pub(all) struct VarId(UInt) derive (Show, Eq, Hash)

pub fn VarId::op_add(self: VarId, other: VarId) -> VarId {
    self.inner() + other.inner()
}

pub(all) struct LabelId(UInt) derive (Eq, Hash, Show)

pub(all) enum JumpCond {
    Equ; Neq; Lss; Leq; Gtr; Geq
} derive (Show)

pub fn JumpCond::negate(self: JumpCond) -> JumpCond {
    match self {
        Equ => Neq
        Neq => Equ
        Lss => Geq
        Leq => Gtr
        Gtr => Leq
        Geq => Lss
    }
}

pub(all) enum Loc {
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

pub(all) enum LIR {
    Ctl(op~: ControlOp)
    Set(dst~: Loc, val~: UInt16)
    Mem(dst~: Loc, addr~: Loc, load~: Bool, offset~: UInt16)
    Alu(dst~: Loc, src1~: Loc, src2~: Loc, op~: AluOp)
    Jmp(dst~: Loc, cond~: LIRCond)
    Label(LabelId)
} derive (Show)

pub fn LIR::variables(self: LIR) -> Array[VarId] {
    let vars = match self {
        Ctl(_) => []
        Set(dst~, val=_) => dst.variables()
        Mem(dst~, addr~, load=_, offset=_) => dst.variables() + addr.variables()
        Alu(dst~, src1~, src2~, op=_) => dst.variables() + src1.variables() + src2.variables()
        Jmp(dst~, cond=_) => dst.variables()
        Label(_) => []
    }

    let unique = Set::from_array(vars).to_array()
    unique
}

pub(all) struct VarIdCounter {
    mut next_var_id: VarId
    fixed_temp_reg: Bool
}

fn VarIdCounter::next(self: VarIdCounter) -> VarId {
    let var_id = self.next_var_id
    // Increment without relying on Add trait for IRVarId
    self.next_var_id = self.next_var_id.inner() + 1U
    var_id
}

fn VarIdCounter::next_tmp_loc(self: VarIdCounter) -> Loc {
    if self.fixed_temp_reg { Reg(TMP) } else { Var(self.next()) }
}

// TODO: implement https://wikiwand.com/en/articles/Live_variable_analysis
pub fn liveness_intervals(insts: Array[LIR]) -> Array[LivenessInterval] {
    let intervals: Map[VarId, (Int, Int)] = {}

    for i = 0; i < insts.length(); i = i + 1 {
        let vars = insts[i].variables()

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
pub fn allocate_registers(insts: Array[LIR], regs_count~: Int) -> VariableAllocation {
    let intervals = liveness_intervals(insts)
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

pub fn replace_labels(insts: Array[LIR], var_counter~: VarIdCounter) -> Array[LIR] raise InstLoweringError {
    let without_labels: Array[LIR] = []
    let label_pos: Map[LabelId, Int] = {}
    let jump_info_by_set_index: Map[Int, (LabelId, LIRCond)] = {}

    // Execution index increments only for non-label instructions and equals physical index
    let mut exec_index = 0

    for inst in insts {
        match inst {
            LIR::Jmp(dst=Loc::Label(label), cond~) => {
                let jmp_offset_loc = var_counter.next_tmp_loc()

                // record where to patch (index of the Set)
                let set_index = without_labels.length()
                jump_info_by_set_index[set_index] = (label, cond)

                // emit placeholder SET and placeholder ALU (op fixed later)
                without_labels.push(LIR::Set(dst=jmp_offset_loc, val=0))
                without_labels.push(LIR::Alu(
                    dst=Loc::Reg(Reg::PC),
                    src1=Loc::Reg(Reg::PC),
                    src2=jmp_offset_loc,
                    op=AluOp::Add, // placeholder; fixed in second pass
                ))

                exec_index += 2
            }
            LIR::Label(label) => {
                // label points to the next non-label instruction
                label_pos[label] = exec_index
                // do not emit label into final stream
            }
            _ => {
                without_labels.push(inst)
                exec_index += 1
            }
        }
    }

    // Second pass: fix jump immediates and ALU ops
    for set_index, info in jump_info_by_set_index {
        let (label, cond) = info
        // ALU executes right after SET
        let alu_exec_index = set_index + 1

        let target_pos = match label_pos.get(label) {
            Some(pos) => pos
            None => raise MissingLabel(label)
        }

        let delta = target_pos - alu_exec_index
        let is_forward = delta >= 0
        let abs_delta = if is_forward { delta } else { -delta }

        // Range check against Inst::Set 11-bit immediate (0..0x7ff)
        if abs_delta > 0x7FF {
            // TODO: support long jumps
            raise JumpOutOfBounds
        }

        // Patch SET immediate
        match without_labels[set_index] {
            LIR::Set(dst~, val=_) => {
                without_labels[set_index] = LIR::Set(dst~, val=abs_delta.to_uint16())
            }
            _ => abort("unexpected instruction during jump SET fixup")
        }

        // Patch ALU op based on direction and condition
        let alu_index = set_index + 1
        match without_labels[alu_index] {
            LIR::Alu(dst~, src1~, src2~, op=_) => {
                let new_op: AluOp = match cond {
                    Always => if is_forward { Add } else { Sub }
                    IfZero => if is_forward { AddIfZero } else { SubIfZero }
                    IfNotZero => if is_forward { AddIfNotZero } else { SubIfNotZero }
                    IfCarry => if is_forward { AddIfCarry } else { SubIfCarry }
                    IfNotCarry => if is_forward { AddIfNotCarry } else { SubIfNotCarry }
                }

                without_labels[alu_index] = LIR::Alu(
                    dst~, src1~, src2~, op=new_op,
                )
            }
            _ => abort("unexpected instruction during jump ALU fixup")
        }
    }

    without_labels
}

pub fn allocate(insts: Array[LIR], regs_count~: Int = 5) -> Array[LIR] {
    let alloc = allocate_registers(insts, regs_count~)

    insts.map(inst => match inst {
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
        LIR::Label(_) => inst
    })
}

suberror InstLoweringError {
    UnexpectedJmp
    UnexpectedLabel
    InvalidLoc(Loc)
    JumpOutOfBounds
    MissingLabel(LabelId)
    Pseudo(PseudoLoweringError)
} derive (Show)

pub fn lower_lir_to_inst(insts: Array[LIR]) -> Array[Inst] raise InstLoweringError {
    let lowered = Array::new(capacity=insts.length())

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

    for inst in insts {
        match inst {
            LIR::Ctl(op~) => {
                lowered.push(Inst::Ctl(op=op))
            }
            LIR::Set(dst~, val~) => {
                lowered.push(Inst::Set(dst=get_reg(dst), val~))
            }
            LIR::Mem(dst~, addr~, load~, offset~) => {
                lowered.push(Inst::Mem(
                    dst=get_reg(dst),
                    addr=get_reg(addr),
                    load~,
                    offset~,
                ))
            }
            LIR::Alu(dst~, src1~, src2~, op~) => {
                lowered.push(Inst::Alu(
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
    lowered.push(Ctl(op=Halt))

    lowered
}

pub struct LowerIROutput {
    without_labels: Array[LIR]
    allocated: Array[LIR]
    insts: Array[Inst]
}

pub fn lower_pseudo_to_lir(pseudo: Array[PseudoInst], var_counter~: VarIdCounter) -> Array[LIR] raise InstLoweringError {
    match (try? lower_many(pseudo, var_counter)) {
        Err(e) => raise Pseudo(e)
        Ok(lir) => lir
    }
}

pub fn lower_lir_to_insts(lir: Array[LIR], var_counter~: VarIdCounter) -> LowerIROutput raise InstLoweringError {
    let without_labels = replace_labels(lir, var_counter~)
    let allocated = allocate(without_labels)
    let insts = lower_lir_to_inst(allocated)

    {
        without_labels,
        allocated,
        insts,
    }
}
