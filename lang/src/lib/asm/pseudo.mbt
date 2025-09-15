
pub(all) enum PseudoInst[T] {
    Halt
    Setz; Clrz // Set Zero Flag, Clear Zero Flag
    Setc; Clrc // Set Carry Flag, Clear Carry Flag
    Load(dst~: T, addr~: T, offset~: UInt16)
    Store(dst~: T, src~: T, offset~: UInt16)
    Move(dst~: T, src~: T)
    Cmp(src1~: T, src2~: T) // Compare
    Setw(dst~: T, val~: UInt16) // Set Word
    Add(dst~: T, src1~: T, src2~: T)
    Sub(dst~: T, src1~: T, src2~: T)
    Adc(dst~: T, src1~: T, src2~: T) // Add with Carry
    Sbc(dst~: T, src1~: T, src2~: T) // Subtract with Carry
    Inc(dst~: T) // Increment
    Dec(dst~: T) // Decrement
    Inc2(dst~: T, src~: T) // dst = src + 1
    Dec2(dst~: T, src~: T) // dst = src - 1
    And(dst~: T, src1~: T, src2~: T)
    Nand(dst~: T, src1~: T, src2~: T)
    Or(dst~: T, src1~: T, src2~: T)
    Xor(dst~: T, src1~: T, src2~: T)
    Shl(dst~: T, src~: T, amt~: T) // Shift Left
    Shr(dst~: T, src~: T, amt~: T) // Shift Right
    Not(dst~: T)
    Not2(dst~: T, src~: T) // dst = not src
    Jmp(dst~: LabelId) // Jump
    Jeq(dst~: LabelId, src1~: T, src2~: T) // Jump if Equal
    Jne(dst~: LabelId, src1~: T, src2~: T) // Jump if Not Equal
    Jlt(dst~: LabelId, src1~: T, src2~: T) // Jump if Less Than
    Jgt(dst~: LabelId, src1~: T, src2~: T) // Jump if Greater Than
    Jle(dst~: LabelId, src1~: T, src2~: T) // Jump if Less Than or Equal
    Jge(dst~: LabelId, src1~: T, src2~: T) // Jump if Greater Than or Equal
    Jc(dst~: LabelId) // Jump on carry set
    Jnc(dst~: LabelId) // Jump on carry clear
    Jz(dst~: LabelId) // Jump on zero set
    Jnz(dst~: LabelId) // Jump on zero clear
    Push(val~: T) // Push value onto stack
    Pop(dst~: T) // Pop value from stack into dst
    Call(dst~: LabelId) // Call subroutine
    Ret // Return from subroutine
    Nop // No Operation

    LIR(LIR)
    Directive(Directive)
} derive (Show)

pub(all) struct VarId(UInt) derive (Eq, Hash)

pub impl Show for VarId with output(self, logger) {
    logger.write_string("%" + self.inner().to_string())
}

pub fn VarId::op_add(self: VarId, other: VarId) -> VarId {
    self.inner() + other.inner()
}

pub suberror PseudoLoweringError String derive (Show)

// Attempt to represent `n` as a left shift of an 11-bit value
fn decompose_11bit_shl(n: UInt, dst: Reg) -> Array[LIR]? {
    let shl_amount = n.ctz()
    let shl_core = n >> shl_amount
    
    if shl_core <= 0x7ff {
        Some([
            Set(dst~, val=shl_core.reinterpret_as_int().to_uint16()),
            Set(dst=TMP, val=shl_amount.to_uint16()),
            Alu(dst~, src1=dst, src2=TMP, op=Shl),
        ])
    } else {
        None
    }
}

pub(open) trait LabelContext {
    next_label(Self) -> LabelId
}

priv struct LabelContextImpl {
    mut next_id: UInt
}

impl LabelContext for LabelContextImpl with next_label(self) -> LabelId {
    let id = self.next_id
    self.next_id += 1
    LabelId(id)
}

pub fn PseudoInst::lower(self: PseudoInst[Reg], ctx: &LabelContext) -> Array[LIR] raise PseudoLoweringError {
  match self {
    LIR(Set(dst=_, val~)) if val > 0x7ff => {
      raise PseudoLoweringError("`set` instruction value exceeds 11 bits: \{val}, use the `setw` pseudo-instruction instead")
    }
    LIR(lir) => [lir]
    Directive(dir) => [Directive(dir)]
    Halt => [Ctl(op=Halt)]
    Setz => [Ctl(op=Setz)]
    Clrz => [Ctl(op=Clrz)]
    Setc => [Ctl(op=Setc)]
    Clrc => [Ctl(op=Clrc)]
    Setw(dst~, val~) => {
        let val_uint = val.to_uint()

        // A fun little puzzle would be to find the optimal way (min instructions) to get to `val`
        if val <= 0x7ff {
            [Set(dst~, val~)]
        } else if val == 0xffff {
            [Alu(dst~, src1=Z, src2=Z, op=Dec)]
        } else if val >= (0xffff - 0x7ff) {
            let sub_val = (0x1000).to_uint16() - val

            [
                Set(dst=TMP, val=sub_val),
                Alu(dst~, src1=Z, src2=TMP, op=Sub),
            ]
        } else {
            // Check if `val` can be represented as a left shift of an 11-bit value
            if decompose_11bit_shl(val_uint, dst) is Some(insts) {
                return insts
            } else if decompose_11bit_shl(val_uint - 1, dst) is Some(insts) {
                // If not, check `val - 1`
                return [
                    ..insts,
                    Alu(dst~, src1=dst, src2=Z, op=Inc),
                ]
            } else if decompose_11bit_shl(val_uint + 1, dst) is Some(insts) {
                // If not, check `val + 1`
                return [
                    ..insts,
                    Alu(dst~, src1=dst, src2=Z, op=Dec),
                ]
            }

            // Fallback to a general strategy
            let high = (val >> 8) & 0xff
            let low = val & 0xff

            [
                Set(dst~, val=high),
                Set(dst=TMP, val=8),
                Alu(dst~, src1=dst, src2=TMP, op=Shl),
                Set(dst=TMP, val=low),
                Alu(dst~, src1=dst, src2=TMP, op=Or),
            ]
        }
    }
    // TODO: Support offsets
    Load(dst~, addr~, offset~) => [Mem(dst~, addr~, load=true, offset~)]
    Store(dst~, src~, offset~) => [Mem(dst=src, addr=dst, load=false, offset~)]
    Move(dst~, src~) => [Alu(dst~, src1=src, src2=Z, op=Add)]
    Cmp(src1~, src2~) => [Alu(dst=Z, src1~, src2~, op=Sub)]
    Add(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=Add)]
    Sub(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=Sub)]
    And(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=And)]
    Adc(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=Adc)]
    Sbc(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=Sbc)]
    Inc(dst~) => [Alu(dst~, src1=dst, src2=Z, op=Inc)]
    Dec(dst~) => [Alu(dst~, src1=dst, src2=Z, op=Dec)]
    Inc2(dst~, src~) => [Alu(dst~, src1=src, src2=Z, op=Inc)]
    Dec2(dst~, src~) => [Alu(dst~, src1=src, src2=Z, op=Dec)]
    Nand(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=Nand)]
    Or(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=Or)]
    Xor(dst~, src1~, src2~) => [Alu(dst~, src1~, src2~, op=Xor)]
    Shl(dst~, src~, amt~) => [Alu(dst~, src1=src, src2=amt, op=Shl)]
    Shr(dst~, src~, amt~) => [Alu(dst~, src1=src, src2=amt, op=Shr)]
    Not(dst~) => [Alu(dst~, src1=dst, src2=dst, op=Nand)]
    Not2(dst~, src~) => [Alu(dst~, src1=src, src2=src, op=Nand)]
    Jmp(dst~) => [Jmp(dst~, cond=Always)]
    Jeq(dst~, src1~, src2~) => [
      Alu(dst=Z, src1~, src2~, op=Sub),
      Jmp(dst~, cond=IfZero),
    ]
    Jne(dst~, src1~, src2~) => [
      Alu(dst=Z, src1~, src2~, op=Sub),
      Jmp(dst~, cond=IfNotZero),
    ]
    Jlt(dst~, src1~, src2~) => [
      Alu(dst=Z, src1~, src2~, op=Sub),
      Jmp(dst~, cond=IfNotCarry),
    ]
    Jgt(dst~, src1~, src2~) => {
        // src1 > src2 iff carry == 1 AND zero == 0
        let skip_zero_check_label = ctx.next_label()

        [
            Alu(dst=Z, src1~, src2~, op=Sub),
            Jmp(dst=skip_zero_check_label, cond=IfNotCarry),
            Jmp(dst~, cond=IfNotZero),
            Label(skip_zero_check_label),
        ]
    }
    Jle(dst~, src1~, src2~) => [
      // src1 <= src2 iff carry == 0 OR zero == 1
      Alu(dst=Z, src1~, src2~, op=Sub),
      Jmp(dst~, cond=IfNotCarry),
      Jmp(dst~, cond=IfZero),
    ]
    Jge(dst~, src1~, src2~) => [
      Alu(dst=Z, src1~, src2~, op=Sub),
      Jmp(dst~, cond=IfCarry),
    ]
    Jc(dst~) => [Jmp(dst~, cond=IfCarry)]
    Jnc(dst~) => [Jmp(dst~, cond=IfNotCarry)]
    Jz(dst~) => [Jmp(dst~, cond=IfZero)]
    Jnz(dst~) => [Jmp(dst~, cond=IfNotZero)]
    Push(val~) => [
        Store(dst=SP, src=val, offset=0),
        Dec(dst=SP),
    ] |> lower_many(ctx~)
    Pop(dst~) => [
        Inc(dst=SP),
        Load(dst~, addr=SP, offset=0),
    ] |> lower_many(ctx~)
    Call(dst~) => {
        [
            // skip next 5 instructions which are part of the call pseudo-instruction itself
            LIR(Set(dst=TMP, val=5)),
            Add(dst=TMP, src1=TMP, src2=PC),
            Push(val=TMP), // 2 instructions
            // TODO: Handle Jumps to arbitrary locations which might take more than 2 instructions
            Jmp(dst~), // 2 instructions
        ] |> lower_many(ctx~)
    }
    Ret => [Pop(dst=PC)] |> lower_many(ctx~)
    Nop => [Set(dst=Z, val=0)]
  }
}

fn lower_many(insts: Array[PseudoInst[Reg]], ctx~: &LabelContext) -> Array[LIR] raise PseudoLoweringError {
    insts.map(inst => inst.lower(ctx)).flatten()
}
