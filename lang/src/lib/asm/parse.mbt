
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
              Some(op) => Some(LIR(Ctl(op~)))
              None => raise ParserError("Invalid control operation code")
            }
        }
        Some(Set) => {
            self.advance()
            let dst = self.expect_loc()
            let val = self.expect_const()
            Some(LIR(Set(dst~, val~)))
        }
        Some(Mem) => {
            self.advance()
            let dst = self.expect_loc()
            let addr = self.expect_loc()
            let load = self.expect_const() == 1
            let offset = self.expect_const()
            Some(LIR(Mem(dst~, addr~, load~, offset~)))
        }
        Some(Load) => {
            self.advance()
            let (dst, addr) = self.expect_ll()
            Some(Load(dst~, addr~))
        }
        Some(Store) => {
            self.advance()
            let (dst, src) = self.expect_ll()
            Some(Store(dst~, src~))
        }
        Some(Move) => {
            self.advance()
            let (dst, src) = self.expect_ll()
            Some(Move(dst~, src~))
        }
        Some(Cmp) => {
            self.advance()
            let (src1, src2) = self.expect_ll()
            Some(Cmp(src1~, src2~))
        }
        Some(Alu) => {
            self.advance()
            let dst = self.expect_loc()
            let src1 = self.expect_loc()
            let src2 = self.expect_loc()
            let op_code = self.expect_const().to_uint()

            match AluOp::decode(op_code) {
                Some(op) => Some(LIR(Alu(dst~, src1~, src2~, op~)))
                None => raise ParserError("Invalid ALU operation code")
            }
        }
        Some(LabelDef(label)) => {
            self.advance()
            let label_id = self.label_ids.get(label).unwrap()
            Some(LIR(Label(label_id)))
        }
        Some(Label(label)) => {
            if !self.label_ids.contains(label) {
                raise ParserError("Undefined label: '\{label}'")
            }

            raise ParserError("Unexpected label: '\{label}'")
        }
        Some(Setw) => {
            self.advance()
            let dst = self.expect_loc()
            let val = self.expect_const()
            Some(Setw(dst~, val~))
        }
        Some(Add) => {
            self.advance()
            let (dst, src1, src2) = self.expect_lll()
            Some(Add(dst~, src1~, src2~))
        }
        Some(Sub) => {
            self.advance()
            let (dst, src1, src2) = self.expect_lll()
            Some(Sub(dst~, src1~, src2~))
        }
        Some(Inc) => {
            self.advance()
            let dst = self.expect_loc()
            Some(Inc(dst~))
        }
        Some(Dec) => {
            self.advance()
            let dst = self.expect_loc()
            Some(Dec(dst~))
        }
        Some(Inc2) => {
            self.advance()
            let (dst, src) = self.expect_ll()
            Some(Inc2(dst~, src~))
        }
        Some(Dec2) => {
            self.advance()
            let (dst, src) = self.expect_ll()
            Some(Dec2(dst~, src~))
        }
        Some(Not) => {
            self.advance()
            let dst = self.expect_loc()
            Some(Not(dst~))
        }
        Some(Not2) => {
            self.advance()
            let (dst, src) = self.expect_ll()
            Some(Not2(dst~, src~))
        }
        Some(Shl) => {
            self.advance()
            let (dst, src, amt) = self.expect_lll()
            Some(Shl(dst~, src~, amt~))
        }
        Some(Shr) => {
            self.advance()
            let (dst, src, amt) = self.expect_lll()
            Some(Shr(dst~, src~, amt~))
        }
        Some(Halt) => {
            self.advance()
            Some(Halt)
        }
        Some(Setz) => {
            self.advance()
            Some(Setz)
        }
        Some(Clrz) => {
            self.advance()
            Some(Clrz)
        }
        Some(Setc) => {
            self.advance()
            Some(Setc)
        }
        Some(Clrc) => {
            self.advance()
            Some(Clrc)
        }
        Some(Jmp) => {
            self.advance()
            let dst = self.expect_loc()
            Some(Jmp(dst~))
        }
        Some(Jeq) => {
            self.advance()
            let (dst, src1, src2) = self.expect_lll()
            Some(Jeq(dst~, src1~, src2~))
        }
        Some(Jne) => {
            self.advance()
            let (dst, src1, src2) = self.expect_lll()
            Some(Jne(dst~, src1~, src2~))
        }
        Some(Jlt) => {
            self.advance()
            let (dst, src1, src2) = self.expect_lll()
            Some(Jlt(dst~, src1~, src2~))
        }
        Some(Jgt) => {
            self.advance()
            let (dst, src1, src2) = self.expect_lll()
            Some(Jgt(dst~, src1~, src2~))
        }
        Some(Jle) => {
            self.advance()
            let (dst, src1, src2) = self.expect_lll()
            Some(Jle(dst~, src1~, src2~))
        }
        Some(Jge) => {
            self.advance()
            let (dst, src1, src2) = self.expect_lll()
            Some(Jge(dst~, src1~, src2~))
        }
        Some(Jpc) => {
            self.advance()
            let dst = self.expect_loc()
            Some(Jpc(dst~))
        }
        Some(Jpnc) => {
            self.advance()
            let dst = self.expect_loc()
            Some(Jpnc(dst~))
        }
        Some(Jpz) => {
            self.advance()
            let dst = self.expect_loc()
            Some(Jpz(dst~))
        }
        Some(Jpnz) => {
            self.advance()
            let dst = self.expect_loc()
            Some(Jpnz(dst~))
        }
        _ => None
    }
}

pub fn parse(tokens: Array[Token]) -> Array[PseudoInst] raise ParserError {
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

    pseudo_insts
}
