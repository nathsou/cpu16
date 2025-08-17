
pub(all) struct VarId(UInt) derive (Show, Eq, Hash)

pub fn VarId::op_add(self: VarId, other: VarId) -> VarId {
    self.inner() + other.inner()
}

pub(all) struct LabelId(UInt) derive (Eq, Hash, Show)

pub(all) enum JumpCond {
    Equ; Neq; Lss; Leq; Gtr; Geq
} derive (Show)

pub fn negate(self: JumpCond) -> JumpCond {
    match self {
        Equ => Neq
        Neq => Equ
        Lss => Geq
        Leq => Gtr
        Gtr => Leq
        Geq => Lss
    }
}

pub(all) enum IR {
    Set(dst~: VarId, val~: Int)
    Load(dst~: VarId, src~: VarId)
    Store(dst~: VarId, src~: VarId)
    Move(dst~: VarId, src~: VarId)
    Add(dst~: VarId, src1~: VarId, src2~: VarId)
    Sub(dst~: VarId, src1~: VarId, src2~: VarId)
    Mul(dst~: VarId, src1~: VarId, src2~: VarId)
    Div(dst~: VarId, src1~: VarId, src2~: VarId)
    Mod(dst~: VarId, src1~: VarId, src2~: VarId)
    Not(dst~: VarId, src~: VarId)
    And(dst~: VarId, src1~: VarId, src2~: VarId)
    Or(dst~: VarId, src1~: VarId, src2~: VarId)
    Xor(dst~: VarId, src1~: VarId, src2~: VarId)
    Jump(label~: LabelId)
    JumpIf(label~: LabelId, cond~: JumpCond, lhs~: VarId, rhs~: VarId)
    Label(LabelId)
} derive (Show)
