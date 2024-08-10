
pub enum UnaryOp {
    Not
} derive (Show)

pub enum BinaryOp {
    Add
    Sub
    Mul
    Div
    Mod
    And
    Or
    Xor
    Eq
    Neq
    Lss
    Gtr
    Leq
    Geq
} derive (Show)

pub enum Const {
    Integer(Int, IntKind)
    Boolean(Bool)
} derive (Show)

pub enum Expr {
    Const(Const)
    UnaryOp(UnaryOp, Expr)
    BinaryOp(Expr, BinaryOp, Expr)
    If(Expr, Expr, Option[Expr])
} derive (Show)
