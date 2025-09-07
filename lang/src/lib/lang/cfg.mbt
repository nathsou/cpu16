
pub struct BasicBlock {
    id: Int
    items: Array[TAC2]
    predecessors: Array[BasicBlock]
    successors: Array[BasicBlock]
}

pub impl Eq for BasicBlock with equal(self, other) {
    self.id == other.id
}

pub impl Show for BasicBlock with output(self, logger: &Logger) {
    let preds = self.predecessors.map(bb => "BB" + bb.id.to_string()).join(", ")
    let succs = self.successors.map(bb => "BB" + bb.id.to_string()).join(", ")
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
            Jump(_) | JumpIf(_) | Call(_) | Return(_) => {
                // the next instruction after a branching instruction is a leader
                insert_leader_index(i + 1)
            }
            Func(..) => {
                // TODO: Handle functions
                ()
            }
            _ => ()
        }
    }

    leaders
}

fn _collect_basic_blocks(items: Array[TAC2]) -> Array[BasicBlock] {
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
            predecessors: [],
            successors: [],
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

    // fn connect(a: BasicBlock, b: BasicBlock) {
    //   if !a.successors.contains(b) {
    //     a.successors.push(b)
    //   }

    //   if !b.predecessors.contains(a) {
    //     b.predecessors.push(a)
    //   }
    // }

    // for index, bb in basic_blocks {
    //   if bb.items.last() is Some(Jmp(dst=Label(label_id), cond=_)) {
    //     match bb_by_label.get(label_id) {
    //       Some(target_bb) => connect(bb, target_bb)
    //       None => println("Jump to unknown label: {\{label_id}}")
    //     }
    //   }

    //   // fallthrough to the next basic block
    //   if index < basic_blocks.length() - 1 {
    //     let next_bb = basic_blocks[index + 1]
    //     connect(bb, next_bb)
    //   }
    // }
    
    basic_blocks
}
