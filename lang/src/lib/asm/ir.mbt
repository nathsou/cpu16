
pub(all) struct IRVarId(UInt) derive (Show, Eq, Hash)

pub fn IRVarId::op_add(self: IRVarId, other: IRVarId) -> IRVarId {
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
    Set(dst~: IRVarId, val~: Int)
    Load(dst~: IRVarId, src~: IRVarId)
    Store(dst~: IRVarId, src~: IRVarId)
    Move(dst~: IRVarId, src~: IRVarId)
    Add(dst~: IRVarId, src1~: IRVarId, src2~: IRVarId)
    Sub(dst~: IRVarId, src1~: IRVarId, src2~: IRVarId)
    Mul(dst~: IRVarId, src1~: IRVarId, src2~: IRVarId)
    Div(dst~: IRVarId, src1~: IRVarId, src2~: IRVarId)
    Mod(dst~: IRVarId, src1~: IRVarId, src2~: IRVarId)
    Not(dst~: IRVarId, src~: IRVarId)
    And(dst~: IRVarId, src1~: IRVarId, src2~: IRVarId)
    Or(dst~: IRVarId, src1~: IRVarId, src2~: IRVarId)
    Xor(dst~: IRVarId, src1~: IRVarId, src2~: IRVarId)
    Jump(label~: LabelId)
    JumpIf(label~: LabelId, cond~: JumpCond, lhs~: IRVarId, rhs~: IRVarId)
    Label(LabelId)
} derive (Show)
