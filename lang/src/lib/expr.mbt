
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
} derive (Show)

pub enum Const {
    Integer(Int)
} derive (Show)

pub enum Expr {
    Const(Const)
    UnaryOp(UnaryOp, Expr)
    BinaryOp(Expr, BinaryOp, Expr)
} derive (Show)

