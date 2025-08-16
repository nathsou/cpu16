
pub struct Parser {
    tokens: Array[Token]
    mut index: Int
}

pub fn Parser::new(tokens: Array[Token]) -> Parser {
    {
        tokens,
        index: 0
    }
}

suberror ParserError String derive (Show)

fn Parser::peek(self: Parser) -> Token? {
    if self.index < self.tokens.length() {
        Some(self.tokens[self.index])
    } else {
        None
    }
}

fn advance(self: Parser) -> Unit {
    self.index += 1
}

pub fn expect_reg(self: Parser) -> Reg raise ParserError {
    match self.peek() {
        Some(Token::Reg(reg)) => {
            self.advance()
            reg
        }
        _ => raise ParserError("Expected a register")
    }
}

pub fn expect_const(self: Parser) -> UInt16 raise ParserError {
    match self.peek() {
        Some(Token::Const(value~, base=_)) => {
            self.advance()
            value
        }
        _ => raise ParserError("Expected a constant value")
    }
}

fn skip_comments(self: Parser) -> Unit {
    while self.index < self.tokens.length() {
        match self.peek() {
            Some(Token::Comment(_)) => {
                self.advance()
            }
            _ => break
        }
    }
}

pub fn parse_inst(self: Parser) -> Inst? raise ParserError {
    self.skip_comments()

    match self.peek() {
        Some(Token::Ctl) => {
            self.advance()

            match ControlOp::decode(self.expect_const().to_uint()) {
              Some(op) => Some(Inst::Ctl(op~))
              None => raise ParserError("Invalid control operation code")
            }
        }
        Some(Token::Set) => {
            self.advance()
            let dst = self.expect_reg()
            let val = self.expect_const().to_uint()
            Some(Inst::Set(dst~, val~))
        }
        Some(Token::Mem) => {
            self.advance()
            let dst = self.expect_reg()
            let addr = self.expect_reg()
            let load = self.expect_const() == 1
            let offset = self.expect_const().to_uint()
            Some(Inst::Mem(dst~, addr~, load~, offset~))
        }
        Some(Token::Alu) => {
            self.advance()
            let dst = self.expect_reg()
            let src1 = self.expect_reg()
            let src2 = self.expect_reg()
            let op_code = self.expect_const().to_uint()

            match AluOp::decode(op_code) {
                Some(op) => Some(Inst::Alu(dst~, src1~, src2~, op~))
                None => raise ParserError("Invalid ALU operation code")
            }
        }
        _ => None
    }
}

pub fn parse(tokens: Array[Token]) -> Array[Inst] raise ParserError {
    let parser = Parser::new(tokens)
    let instructions = []

    while parser.index < parser.tokens.length() {
        match parser.parse_inst() {
            Some(inst) => {
                instructions.push(inst)
            }
            None => break
        }
    }

    instructions
}
