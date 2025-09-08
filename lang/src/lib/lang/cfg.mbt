
pub struct BasicBlock {
    id: Int
    items: Array[TAC2]
    predecessors: Set[BasicBlock]
    successors: Set[BasicBlock]
}

pub impl Eq for BasicBlock with equal(self, other) {
    self.id == other.id
}

pub impl Hash for BasicBlock with hash_combine(self, hasher: Hasher) {
    hasher.combine_int(self.id)
}

pub impl Show for BasicBlock with output(self, logger: &Logger) {
    let preds = self.predecessors.iter().map(bb => "BB\{bb.id}").join(", ")
    let succs = self.successors.iter().map(bb => "BB\{bb.id}").join(", ")
    logger.write_string("BB" + self.id.to_string() + ": [preds: {\{preds}}] [succs: {\{succs}}]\n")

    for item in self.items {
        logger.write_string("    " + item.to_string() + "\n")
    }
}

// pub struct CFG {
//   entry: BasicBlock
// }

fn collect_basic_block_leaders(items: Array[TAC2]) -> Array[Int] {
    let leaders: Array[Int] = []

    fn insert_leader_index(idx: Int) {
        // avoid duplicates
        if leaders.is_empty() || leaders[leaders.length() - 1] != idx {
            leaders.push(idx)
        }
    }

    // the first instruction is always a leader
    insert_leader_index(0)

    for i in 0..<items.length() {
        let item = items[i]

        match item {
            Label(_) => {
                // the target of a jump instruction is a leader
                insert_leader_index(i)
            }
            Jump(_) | JumpIf(_) | Return(_) => {
                // the next instruction after a branching instruction is a leader
                // Note: The next isntruction after a call is not a leader
                // because we are not doing inter-procedural analysis
                insert_leader_index(i + 1)
            }
            _ => ()
        }
    }

    leaders
}

fn collect_basic_blocks(items: Array[TAC2]) -> Array[BasicBlock] {
    let leader_indices = collect_basic_block_leaders(items)
    let basic_blocks: Array[BasicBlock] = []
    let bb_by_label: Map[@asm.LabelId, BasicBlock] = {}

    // Starting from a leader, the set of all following instructions until and not including the next leader
    // is the basic block corresponding to the starting leader.
    for i in 1..<leader_indices.length() {
        let prev_leader = leader_indices[i - 1]
        let curr_leader = leader_indices[i]

        let bb: BasicBlock = {
            id: basic_blocks.length(),
            items: [],
            predecessors: Set::new(),
            successors: Set::new(),
        }

        for j in prev_leader..<curr_leader {
            let item = items[j]

            if item is Label(label=label_id) {
                bb_by_label[label_id] = bb
            }
        
            bb.items.push(item)
        }

        basic_blocks.push(bb)
    }

    fn connect(a: BasicBlock, b: BasicBlock) {
        a.successors.add(b)
        b.predecessors.add(a)
    }

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
    
    basic_blocks
}
