
priv struct CFG {
    blocks: Array[BasicBlock]
}

fn CFG::from(blocks: Array[BasicBlock]) -> CFG {
    {
        blocks,
    }
}

priv struct BasicBlock {
    id: Int
    offset: Int // offset in the function's instruction array
    items: Array[TAC2]
    predecessors: Set[BasicBlock]
    successors: Set[BasicBlock]
    vars: LivenessVars
    mut live_in: Set[@asm.VarId]
    mut live_out: Set[@asm.VarId]
}

impl Eq for BasicBlock with equal(self, other) {
    self.id == other.id
}

impl Hash for BasicBlock with hash_combine(self, hasher: Hasher) {
    hasher.combine_int(self.id)
}

impl Show for BasicBlock with output(self, logger: &Logger) {
    let preds = self.predecessors.iter().map(bb => "BB\{bb.id}").join(", ")
    let succs = self.successors.iter().map(bb => "BB\{bb.id}").join(", ")
    logger.write_string("BB" + self.id.to_string() + ": [preds: {\{preds}}] [succs: {\{succs}}]\n")

    for item in self.items {
        logger.write_string("    " + item.to_string() + "\n")
    }
}

typealias Array[TAC2] as TAC2s

fn TAC2s::collect_basic_block_leaders(self: Array[TAC2]) -> Array[Int] {
    let leaders: Array[Int] = []

    fn insert_leader_index(idx: Int) {
        // avoid duplicates
        if leaders.is_empty() || leaders[leaders.length() - 1] != idx {
            leaders.push(idx)
        }
    }

    // the first instruction is always a leader
    insert_leader_index(0)

    for i in 0..<self.length() {
        let item = self[i]

        match item {
            Label(_) => {
                // the target of a jump instruction is a leader
                insert_leader_index(i)
            }
            Jump(_) | JumpIf(_) | Return(_) => {
                // the next instruction after a branching instruction is a leader
                // Note: The next instruction after a call is not a leader
                // because we are not doing inter-procedural analysis
                insert_leader_index(i + 1)
            }
            _ => ()
        }
    }

    leaders
}

fn TACFunc::cfg(self: TACFunc[@asm.VarId, @asm.VarId]) -> CFG {
    CFG::from(self.collect_basic_blocks())
}

impl Show for CFG with output(self, logger: &Logger) {
    for bb in self.blocks {
        logger.write_string(bb.vars.to_string())
        logger.write_string("live_in:  \{bb.live_in}")
        logger.write_string("live_out: \{bb.live_out}")
        logger.write_string(bb.to_string())
    }
}

fn TACFunc::collect_basic_blocks(self: TACFunc[@asm.VarId, @asm.VarId]) -> Array[BasicBlock] {
    let leader_indices = self.body.collect_basic_block_leaders()
    let basic_blocks: Array[BasicBlock] = []
    let bb_by_label: Map[@asm.LabelId, BasicBlock] = {}

    // Starting from a leader, the set of all following instructions until and not including the next leader
    // is the basic block corresponding to the starting leader.
    for i in 1..<leader_indices.length() {
        let prev_leader = leader_indices[i - 1]
        let curr_leader = leader_indices[i]

        let bb: BasicBlock = {
            id: basic_blocks.length(),
            offset: prev_leader,
            items: [],
            predecessors: Set::new(),
            successors: Set::new(),
            vars: LivenessVars::new(),
            live_in: Set::new(),
            live_out: Set::new(),
        }

        for j in prev_leader..<curr_leader {
            let item = self.body[j]

            if item is Label(label=label_id) {
                bb_by_label[label_id] = bb
            }
        
            bb.items.push(item)
        }

        // collect used/defined variables in this basic block
        for item in bb.items {
            bb.vars.collect(item)
        }

        basic_blocks.push(bb)
    }

    fn connect(a: BasicBlock, b: BasicBlock) {
        a.successors.add(b)
        b.predecessors.add(a)
    }

    // connect basic blocks based on jump instructions
    for index, bb in basic_blocks {
        let (target_label, fallthrough) = match bb.items.last() {
            Some(Jump(label~)) => {
                (Some(label), false)
            }
            Some(JumpIf(label~, ..)) => {
                (Some(label), true)
            }
            _ => (None, true)
        }

        if target_label is Some(label_id) {
            match bb_by_label.get(label_id) {
                Some(target_bb) => connect(bb, target_bb)
                None => println("Jump to unknown label: {\{label_id}}")
            }
        }

        // fallthrough to the next basic block
        if fallthrough && index < basic_blocks.length() - 1 {
            let next_bb = basic_blocks[index + 1]
            connect(bb, next_bb)
        }
    }

    // liveness analysis
    while true {
        let mut changed = false

        for bb in basic_blocks.rev_iter() {
            if bb.liveness_step() {
                changed = true
            }
        }

        if !changed {
            break
        }
    }
    
    basic_blocks
}

priv struct LivenessVars {
    used: Set[@asm.VarId]
    defined: Set[@asm.VarId]
} derive (Show)

fn LivenessVars::new() -> LivenessVars {
    {
        used: Set::new(),
        defined: Set::new(),
    }
}

fn LivenessVars::add_def(self: LivenessVars, v: @asm.VarId) -> Unit {
    self.defined.add(v)
}

fn LivenessVars::add_use(self: LivenessVars, v: @asm.VarId) -> Unit {
    // a variable is in the use[B] set of a basic block B
    // if it is used in B before any assignment to it in B
    if !self.defined.contains(v) {
        self.used.add(v)
    }
}

fn LivenessVars::collect(self: LivenessVars, item: TAC2) -> Unit {
    match item {
        Assign(target~, val=_) => {
            self.add_def(target)
        }
        Move(target~, src~) => {
            self.add_def(target)
            self.add_use(src)
        }
        Unary(target~, op=_, arg~) => {
            self.add_def(target)
            self.add_use(arg)
        }
        Binary(target~, lhs~, op=_, rhs~) => {
            self.add_def(target)
            self.add_use(lhs)
            self.add_use(rhs)
        }
        Store(dst~, src~, offset=_) => {
            self.add_use(dst)
            self.add_use(src)
        }
        Load(target~, addr~, offset=_) => {
            self.add_def(target)
            self.add_use(addr)
        }
        Jump(label=_) => ()
        JumpIf(label=_, cond=_, lhs~, rhs~) => {
            self.add_use(lhs)
            self.add_use(rhs)
        }
        Label(_) => ()
        Func(_) => ()
        GetLocal(target~, index=_) => {
            self.add_def(target)
        }
        SetLocal(index=_, src~) => {
            self.add_use(src)
        }
        Return(value~) => {
            if value is Some(v) {
                self.add_use(v)
            }
        }
        Call(target~, name=_, parameters~) => {
            self.add_def(target)

            for param in parameters {
                self.add_use(param)
            }
        }
    }
}

fn BasicBlock::liveness_step(self: BasicBlock) -> Bool {
    // iterate until reaching a fixed point:

    // live_out[B] = ⋃ in[S] for all successors S of B
    // (A variable is live leaving B if it is live entering any of B's successors)

    // live_in[B] = use[B] ⋃ (out[B] - def[B])
    // (A variable is live entering B if it is either used in B before being defined, or it is live leaving B and is not defined (killed) within B)

    let new_live_out = Set::new()

    for succ in self.successors {
        for v in succ.live_in {
            new_live_out.add(v)
        }
    }

    let new_live_in = self.vars.used.union(self.live_out.difference(self.vars.defined))

    let changed = new_live_out != self.live_out || new_live_in != self.live_in

    self.live_in = new_live_in
    self.live_out = new_live_out 

    changed
}

fn TAC2::vars(self: TAC2) -> LivenessVars {
    let vars = LivenessVars::new()
    vars.collect(self)
    vars
}

// variable -> set of instruction offsets where it is live
typealias Map[@asm.VarId, Set[Int]] as LivePoints

typealias Map[@asm.VarId, (Int, Int)] as LivenessIntervals

fn CFG::collect_live_points(self: CFG) -> LivePoints {
    let live_points: LivePoints = {}

    for bb in self.blocks.rev_iter() {
        live_points.collect(bb)
    }

    live_points
}

fn CFG::liveness_intervals(self: CFG) -> LivenessIntervals {
    self.collect_live_points().intervals()
}

fn LivePoints::collect(self: LivePoints, bb: BasicBlock) -> Unit {
    let mut i = bb.items.length() - 1
    let mut live_now = bb.live_out.copy()

    while i >= 0 {
        // live_now = use(i) ∪ (live_now - def(i))
        let item = bb.items[i]
        let vars = item.vars()
        let offset = bb.offset + i
        live_now = vars.used.union(live_now.difference(vars.defined))

        for v in live_now {
            if !self.contains(v) {
                self[v] = Set::new()
            }

            self[v].add(offset)
        }

        i -= 1
    }
}

fn LivePoints::intervals(self: LivePoints) -> LivenessIntervals {
    self.map((_, offsets) => {
        let min = offsets.iter().minimum().unwrap()
        let max = offsets.iter().maximum().unwrap()
        (min, max)
    })
}
