
pub struct Parser {
    tokens: Array[Token]
    label_ids: Map[String, LabelId]
    mut index: Int
}

pub fn Parser::new(tokens: Array[Token], label_ids: Map[String, LabelId]) -> Parser {
    {
        tokens,
        index: 0,
        label_ids,
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

pub fn expect_loc(self: Parser) -> Loc raise ParserError {
    match self.peek() {
        Some(Token::Reg(reg)) => {
            self.advance()
            Loc::Reg(reg)
        }
        Some(Token::Label(label)) => {
            self.advance()

            match self.label_ids.get(label) {
                Some(label_id) => Loc::Label(label_id)
                None => raise ParserError("Undefined label: \{label}")
            }
        }
        _ => raise ParserError("Expected a location")
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

fn expect_ll(self: Parser) -> (Loc, Loc) raise ParserError {
    let l1 = self.expect_loc()
    let l2 = self.expect_loc()
    (l1, l2)
}

fn expect_lll(self: Parser) -> (Loc, Loc, Loc) raise ParserError {
    let dst = self.expect_loc()
    let src1 = self.expect_loc()
    let src2 = self.expect_loc()
    (dst, src1, src2)
}

pub fn parse_inst(self: Parser) -> PseudoInst? raise ParserError {
    self.skip_comments()

    match self.peek() {
        Some(Ctl) => {
            self.advance()

            match ControlOp::decode(self.expect_const().to_uint()) {
              Some(op) => Some(PseudoInst::LIR(LIR::Ctl(op~)))
              None => raise ParserError("Invalid control operation code")
            }
        }
        Some(Set) => {
            self.advance()
            let dst = self.expect_loc()
            let val = self.expect_const().to_uint()
            Some(PseudoInst::LIR(LIR::Set(dst~, val~)))
        }
        Some(Mem) => {
            self.advance()
            let dst = self.expect_loc()
            let addr = self.expect_loc()
            let load = self.expect_const() == 1
            let offset = self.expect_const().to_uint()
            Some(PseudoInst::LIR(LIR::Mem(dst~, addr~, load~, offset~)))
        }
        Some(Alu) => {
            self.advance()
            let dst = self.expect_loc()
            let src1 = self.expect_loc()
            let src2 = self.expect_loc()
            let op_code = self.expect_const().to_uint()

            match AluOp::decode(op_code) {
                Some(op) => Some(PseudoInst::LIR(LIR::Alu(dst~, src1~, src2~, op~)))
                None => raise ParserError("Invalid ALU operation code")
            }
        }
        Some(LabelDef(_)) => {
            self.advance()
            self.parse_inst() // skip label definition
        }
        Some(Label(label)) => {
            if !self.label_ids.contains(label) {
                raise ParserError("Undefined label: '\{label}'")
            }

            raise ParserError("Unexpected label: '\{label}'")
        }
        Some(Add) => {
            self.advance()
            let (dst, src1, src2) = self.expect_lll()
            Some(PseudoInst::Add(dst~, src1~, src2~))
        }
        Some(Sub) => {
            self.advance()
            let (dst, src1, src2) = self.expect_lll()
            Some(PseudoInst::Sub(dst~, src1~, src2~))
        }
        Some(Inc) => {
            self.advance()
            let dst = self.expect_loc()
            Some(PseudoInst::Inc(dst~))
        }
        Some(Dec) => {
            self.advance()
            let dst = self.expect_loc()
            Some(PseudoInst::Dec(dst~))
        }
        Some(Inc2) => {
            self.advance()
            let (dst, src) = self.expect_ll()
            Some(PseudoInst::Inc2(dst~, src~))
        }
        Some(Dec2) => {
            self.advance()
            let (dst, src) = self.expect_ll()
            Some(PseudoInst::Dec2(dst~, src~))
        }
        Some(Not) => {
            self.advance()
            let dst = self.expect_loc()
            Some(PseudoInst::Not(dst~))
        }
        Some(Not2) => {
            self.advance()
            let (dst, src) = self.expect_ll()
            Some(PseudoInst::Not2(dst~, src~))
        }
        Some(Shl) => {
            self.advance()
            let (dst, src, amt) = self.expect_lll()
            Some(PseudoInst::Shl(dst~, src~, amt~))
        }
        Some(Shr) => {
            self.advance()
            let (dst, src, amt) = self.expect_lll()
            Some(PseudoInst::Shr(dst~, src~, amt~))
        }
        _ => None
    }
}

pub fn parse(tokens: Array[Token]) -> Array[LIR] raise ParserError {
    // collect label definitions
    let label_ids = {
        let mapping: Map[String, LabelId] = {}

        for token in tokens {
            if token is LabelDef(label) {
                match mapping.get(label) {
                    Some(_) => {
                        raise ParserError("Duplicate label definition: '\{label}'")
                    }
                    None => {
                        mapping[label] = LabelId(mapping.size().reinterpret_as_uint())
                    }
                }
            }
        }

        mapping
    }

    let parser = Parser::new(tokens, label_ids)
    let pseudo_insts: Array[PseudoInst] = []

    while parser.index < parser.tokens.length() {
        match parser.parse_inst() {
            Some(inst) => {
                pseudo_insts.push(inst)
            }
            None => break
        }
    }

    pseudo_insts.map(PseudoInst::lower).flatten()
}
