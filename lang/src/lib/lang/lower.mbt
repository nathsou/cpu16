
pub struct PseudoBuilder[T] {
    functions: Map[String, LowerFuncInfo]
    insts: Array[@asm.PseudoInst[T]]
}

struct LowerFuncInfo {
    label_id: @asm.LabelId
    return_type: Type
}

const UNIT_VAR_ID: UInt = 0U

pub fn[T] PseudoBuilder::new() -> PseudoBuilder[T] {
    {
        functions: {},
        insts: [],
    }
}

pub fn[T] PseudoBuilder::emit(self: PseudoBuilder[T], inst: @asm.PseudoInst[T]) -> Unit {
    self.insts.push(inst)
}

suberror IRBuilderError String derive (Show)

pub(all) struct PseudoFunc[T] {
    name: String
    label: @asm.LabelId
    body: Array[@asm.PseudoInst[T]]
}

priv struct RegUse {
    reg: @asm.Reg
    mut var_id: @asm.VarId?
    mut last_used_idx: UInt
}

fn RegUse::touch(self: RegUse, idx: UInt) -> Unit {
    self.last_used_idx = idx
}

priv struct RegAlloc {
    regs: Array[RegUse]
    on_evict: (@asm.VarId, @asm.Reg) -> Unit
    mut counter: UInt
}

fn RegAlloc::new(on_evict~: (@asm.VarId, @asm.Reg) -> Unit) -> RegAlloc {
    {
        regs: [
            { reg: R1, var_id: None, last_used_idx: 0 },
            { reg: R2, var_id: None, last_used_idx: 0 },
            { reg: R3, var_id: None, last_used_idx: 0 },
            { reg: R4, var_id: None, last_used_idx: 0 },
        ],
        on_evict,
        counter: 0,
    }
}

fn RegAlloc::evict_all(self: RegAlloc) -> Unit {
    for r in self.regs {
        if r.var_id is Some(var_id) {
            (self.on_evict)(var_id, r.reg)
            r.var_id = None
        }
    }
}

fn RegAlloc::lookup(self: RegAlloc, var_id: @asm.VarId) -> RegUse? {
    for r in self.regs {
        match r.var_id {
            Some(v) if v == var_id => {
                self.touch(r)
                return Some(r)
            }
            _ => ()
        }
    }

    None
}

fn RegAlloc::touch(self: RegAlloc, r: RegUse) -> Unit {
    r.touch({ self.counter += 1; self.counter })
}

fn RegAlloc::assign(self: RegAlloc, var_id: @asm.VarId) -> @asm.Reg {
    // check if already assigned
    if self.lookup(var_id) is Some(r) {
        self.touch(r)
        return r.reg
    }

    // find free register
    for r in self.regs {
        if r.var_id is None {
            r.var_id = Some(var_id)
            self.touch(r)
            return r.reg
        }
    }

    // evict least recently used register
    let mut lru = self.regs[0]
    for r in self.regs {
        if r.last_used_idx < lru.last_used_idx {
            lru = r
        }
    }

    if lru.var_id is Some(evicted_var_id) {
        (self.on_evict)(evicted_var_id, lru.reg)
    }

    lru.var_id = Some(var_id)
    self.touch(lru)
    lru.reg
}

priv struct MemAlloc {
    offsets: Map[@asm.VarId, UInt16]
    base_offset: UInt16
}

fn MemAlloc::new(base_offset: UInt16) -> MemAlloc {
    { offsets: {}, base_offset }
}

fn MemAlloc::assign(self: MemAlloc, var_id: @asm.VarId) -> UInt16 {
    match self.offsets.get(var_id) {
        Some(offset) => offset
        None => {
            let offset = self.base_offset + self.offsets.size().to_uint16()
            self.offsets[var_id] = offset
            offset
        }
    }
}

pub fn TACFunc::lower(self: TACFunc2, funcs: Map[String, LowerFuncInfo]) -> PseudoFunc[@asm.Reg] raise IRBuilderError {
    let current_func_start_label = if self.body[0] is Label(label=label_id) {
        funcs[self.name] = { return_type: self.return_type, label_id }
        label_id
    } else {
        raise IRBuilderError("function body must start with a label")
    }

    // return address
    let params_offset: UInt16 = 1

    let body: Array[@asm.PseudoInst[@asm.Reg]] = Array::new(capacity=self.body.length())

    fn store(var_id: @asm.VarId, reg: @asm.Reg) -> Unit {
        let offset = var_id.inner().reinterpret_as_int().to_uint16()
        body.push(Store(dst=Z, src=reg, offset~))
    }

    let mut next_reg = @asm.Reg::R1

    fn read_reg(var_id: @asm.VarId) -> @asm.Reg {
        next_reg = match next_reg {
            R1 => R2
            R2 => R3
            R3 => R4
            _ => R1
        }

        let offset = var_id.inner().reinterpret_as_int().to_uint16()
        body.push(Load(dst=next_reg, addr=Z, offset~))

        next_reg
    }

    fn write_reg() -> @asm.Reg {
        next_reg = match next_reg {
            R1 => R2
            R2 => R3
            R3 => R4
            _ => R1
        }

        next_reg
    }

    // fn read_reg(var_id: @asm.VarId) -> @asm.Reg raise IRBuilderError {
    //     if regs.lookup(var_id) is Some(r) {
    //         regs.touch(r)
    //         r.reg
    //     } else {
    //         // The variable is not in a register, so it must be on the stack.
    //         // Get its offset, but do not create a new one.
    //         if mem.offsets.get(var_id) is Some(offset) {
    //             let target = regs.assign(var_id)
    //             body.push(Load(dst=target, addr=SP, offset=spilled_offset + offset))
    //             target
    //         } else {
    //             raise IRBuilderError("Attempted to read '\{var_id}' that is not in a register and was never spilled.")
    //         }
    //     }
    // }

    // fn write_reg(var_id: @asm.VarId) -> @asm.Reg {
    //     regs.assign(var_id)
    // }

    for item in self.body {
        match item {
            TAC::Assign(target~, val~) => {
                let dst = write_reg()
                body.push(Setw(dst~, val=match val {
                    Integer(n, _) => n.to_uint16()
                    Boolean(q) => if q { 1 } else { 0 }
                }))
                store(target, dst)
            }
            TAC::Move(target~, src~) => {
                if target != src {
                    let dst = write_reg()
                    let src = read_reg(src)
                    body.push(Move(dst~, src~))
                    store(target, dst)
                }
            }
            TAC::Unary(target~, op~, arg~) => {
                let dst = write_reg()
                let src = read_reg(arg)

                match op {
                    UnaryOp::Not => {
                        body.push(Not2(dst~, src~))
                    }
                }

                store(target, dst)
            }
            TAC::Binary(target~, lhs~, op~, rhs~) => {
                let dst = write_reg()
                let src1 = read_reg(lhs)
                let src2 = read_reg(rhs)

                match op {
                    Add => body.push(Add(dst~, src1~, src2~))
                    Sub => body.push(Sub(dst~, src1~, src2~))
                    Mul => raise IRBuilderError("multiplication not implemented")
                    Div => raise IRBuilderError("division not implemented")
                    Mod => raise IRBuilderError("modulo not implemented")
                    Shl => body.push(Shl(dst~, src=src1, amt=src2))
                    Shr => body.push(Shr(dst~, src=src1, amt=src2))
                    BitwiseAnd | LogicalAnd => body.push(And(dst~, src1~, src2~))
                    BitwiseOr | LogicalOr => body.push(Or(dst~, src1~, src2~))
                    BitwiseXor => body.push(Xor(dst~, src1~, src2~))
                    Equ | Neq | Lss | Gtr | Leq | Geq => {
                        raise IRBuilderError("comparison operators not supported in binary expressions")
                    }
                }

                store(target, dst)
            }
            TAC::Store(dst~, src~, offset=_) => {
                let dst_reg = write_reg()
                let src = read_reg(src)
                body.push(Store(dst=dst_reg, src~, offset=0))
                store(dst, dst_reg)
            }
            TAC::Load(target~, addr~, offset=_) => {
                let dst = write_reg()
                let addr = read_reg(addr)
                body.push(Load(dst~, addr~, offset=0))
                store(target, dst)
            }
            TAC::Jump(label~) => {
                body.push(Jmp(dst=label))
            }
            TAC::JumpIf(label~, cond~, lhs~, rhs~) => {
                let src1 = read_reg(lhs)
                let src2 = read_reg(rhs)

                let pseudo: @asm.PseudoInst[@asm.Reg] = match cond {
                    Equ => Jeq(dst=label, src1~, src2~)
                    Neq => Jne(dst=label, src1~, src2~)
                    Lss => Jlt(dst=label, src1~, src2~)
                    Gtr => Jgt(dst=label, src1~, src2~)
                    Geq => Jge(dst=label, src1~, src2~)
                    Leq => Jle(dst=label, src1~, src2~)
                }

                body.push(pseudo)
            }
            TAC::Label(label~) => {
                body.push(LIR(Label(label)))
            }
            TAC::Func(_) => @asm.panic_msg("nested functions not supported")
            GetLocal(target~, index~) => {
                let dst = write_reg() 
                body.push(Load(
                    dst~,
                    addr=SP,
                    offset=params_offset + index.reinterpret_as_int().to_uint16()
                ))
                
                store(target, dst) 
            }
            SetLocal(index=_, src=_) => {
                raise IRBuilderError("set_local not supported yet")
            }
            Return(value~) => {
                let is_main = self.name == "main"

                if value is Some(v) {
                    // replace return address with return value on the stack
                    let src = read_reg(v)
                    body.push(Load(dst=TMP, addr=SP, offset=0))
                    body.push(Store(dst=SP, src~, offset=0))

                    if !is_main {
                        body.push(Move(dst=PC, src=TMP))
                    }
                } else if !is_main {
                    body.push(Load(dst=PC, addr=SP, offset=0))
                }

                if is_main {
                    // do not return from main, instead halt directly
                    body.push(Halt)
                }
            }
            TAC::Call(target~, name~, parameters~) => {
                if funcs.get(name) is Some(({ label_id, return_type })) {
                    guard return_type == U16 else {
                        raise IRBuilderError("function return type not supported for '\{name}': '\{return_type}'")
                    }

                    // step 1: Allocate space for return address + parameters
                    let params_offset: UInt16 = 1
                    let allocated_words = params_offset + parameters.length().to_uint16()
                    body.push(Setw(dst=TMP, val=allocated_words))
                    body.push(Sub(dst=SP, src1=SP, src2=TMP))

                    // offset 0: return address

                    // step 2: push parameters from the registers into the new stack frame
                    for i in 0..<parameters.length() {
                        let src = read_reg(parameters[i])
                        body.push(Store(dst=SP, src~, offset=params_offset + i.to_uint16()))
                    }

                    // step 3: call the function
                    body.push(LIR(Set(dst=TMP, val=4))) // return address is 4 instructions ahead
                    body.push(Add(dst=TMP, src1=TMP, src2=PC))
                    body.push(Store(dst=SP, src=TMP, offset=0)) // save return address
                    body.push(Jmp(dst=label_id)) // jump to function

                    // step 4: retrieve return value
                    if return_type != Unit {
                        let dst = write_reg()
                        body.push(Load(dst~, addr=SP, offset=0))
                        store(target, dst)
                    }

                    // step 5: deallocate space
                    body.push(Setw(dst=TMP, val=allocated_words))
                    body.push(Add(dst=SP, src1=SP, src2=TMP))
                } else if name == "@show" {
                    let r = read_reg(parameters[0])
                    body.push(LIR(Ctl(op=Show(r))))
                } else {
                    raise IRBuilderError("call to undeclared function '\{name}'")
                }
            }
        }
    }

    {
        name: self.name,
        label: current_func_start_label,
        body,
    }
}

typealias Array[PseudoFunc[@asm.Reg]] as PseudoFuncs

// no hardware detection of stack overflow, adjust layout of data in 0x0000..0x7FFF to avoid collisions
// depending on program needs (max recursion depth * stack frame size)
pub const STACK_TOP: UInt16 = 0x7fff

fn PseudoFuncs::with_main_fn_call(self: PseudoFuncs) -> Array[@asm.PseudoInst[@asm.Reg]] raise IRBuilderError {
    if self.search_by(f => f.name == "main") is Some(main_idx) {
        let f = self[main_idx]

        let insts: Array[@asm.PseudoInst[@asm.Reg]] = [
            Directive(Origin(addr=@asm.PC_START_ADDR)),
            Setw(dst=SP, val=STACK_TOP),
            Jmp(dst=f.label),
        ]

        for f in self {
            insts.push_iter(f.body.iter())
        }

        insts
    } else {
        raise IRBuilderError("no 'main' function declared")
    }
}
