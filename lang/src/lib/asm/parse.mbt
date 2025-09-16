
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

fn expect_reg(self: Parser) -> Reg raise ParserError {
    match self.peek() {
        Some(Token::Reg(reg)) => {
            self.advance()
            reg
        }
        _ => raise ParserError("Expected a register")
    }
}

pub fn expect_label(self: Parser) -> LabelId raise ParserError {
    match self.peek() {
        Some(Token::Label(label)) => {
            self.advance()

            match self.label_ids.get(label) {
                Some(label_id) => label_id
                None => raise ParserError("Undefined label: '\{label}'")
            }
        }
        _ => raise ParserError("Expected a label")
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

fn expect_rr(self: Parser) -> (Reg, Reg) raise ParserError {
    let r1 = self.expect_reg()
    let r2 = self.expect_reg()
    (r1, r2)
}

fn expect_rrr(self: Parser) -> (Reg, Reg, Reg) raise ParserError {
    let dst = self.expect_reg()
    let src1 = self.expect_reg()
    let src2 = self.expect_reg()
    (dst, src1, src2)
}

pub fn parse_inst(self: Parser) -> PseudoInst[Reg]? raise ParserError {
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
            let dst = self.expect_reg()
            let val = self.expect_const()
            Some(LIR(Set(dst~, val~)))
        }
        Some(Mem) => {
            self.advance()
            let dst = self.expect_reg()
            let addr = self.expect_reg()
            let load = self.expect_const() == 1
            let offset = self.expect_const()
            Some(LIR(Mem(dst~, addr~, load~, offset~)))
        }
        Some(Load) => {
            self.advance()
            let (dst, addr) = self.expect_rr()
            Some(Load(dst~, addr~, offset=0))
        }
        Some(Store) => {
            self.advance()
            let (dst, src) = self.expect_rr()
            Some(Store(dst~, src~, offset=0))
        }
        Some(Move) => {
            self.advance()
            let (dst, src) = self.expect_rr()
            Some(Move(dst~, src~))
        }
        Some(Cmp) => {
            self.advance()
            let (src1, src2) = self.expect_rr()
            Some(Cmp(src1~, src2~))
        }
        Some(Alu) => {
            self.advance()
            let dst = self.expect_reg()
            let src1 = self.expect_reg()
            let src2 = self.expect_reg()
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
        Some(Directive(name)) => {
            self.advance()
            
            match name {
                "org" => {
                    let addr = self.expect_const()
                    Some(Directive(Origin(addr~)))
                }
                "byte" => {
                    let value = self.expect_const()

                    if value > 0xff {
                        raise ParserError("Byte value out of range: \{value}")
                    }

                    Some(Directive(Byte(value.to_byte())))
                }
                "word" => {
                    let value = self.expect_const()
                    Some(Directive(Word(value)))
                }
                _ => raise ParserError("Invalid directive: '.\{name}'")
            }
        }
        Some(Setw) => {
            self.advance()
            let dst = self.expect_reg()
            let val = self.expect_const()
            Some(Setw(dst~, val~))
        }
        Some(Add) => {
            self.advance()
            let (dst, src1, src2) = self.expect_rrr()
            Some(Add(dst~, src1~, src2~))
        }
        Some(Sub) => {
            self.advance()
            let (dst, src1, src2) = self.expect_rrr()
            Some(Sub(dst~, src1~, src2~))
        }
        Some(Inc) => {
            self.advance()
            let dst = self.expect_reg()
            Some(Inc(dst~))
        }
        Some(Dec) => {
            self.advance()
            let dst = self.expect_reg()
            Some(Dec(dst~))
        }
        Some(Inc2) => {
            self.advance()
            let (dst, src) = self.expect_rr()
            Some(Inc2(dst~, src~))
        }
        Some(Dec2) => {
            self.advance()
            let (dst, src) = self.expect_rr()
            Some(Dec2(dst~, src~))
        }
        Some(Not) => {
            self.advance()
            let dst = self.expect_reg()
            Some(Not(dst~))
        }
        Some(Not2) => {
            self.advance()
            let (dst, src) = self.expect_rr()
            Some(Not2(dst~, src~))
        }
        Some(Shl) => {
            self.advance()
            let (dst, src, amt) = self.expect_rrr()
            Some(Shl(dst~, src~, amt~))
        }
        Some(Shr) => {
            self.advance()
            let (dst, src, amt) = self.expect_rrr()
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
            let dst = self.expect_label()
            Some(Jmp(dst~))
        }
        Some((Jeq | Jne | Jlt | Jgt | Jle | Jge | Jc | Jnc | Jz | Jnz) as cond) => {
            self.advance()
            let dst = self.expect_label()
            let (src1, src2) = self.expect_rr()

            Some(match cond {
                Jeq => Jeq(dst~, src1~, src2~)
                Jne => Jne(dst~, src1~, src2~)
                Jlt => Jlt(dst~, src1~, src2~)
                Jgt => Jgt(dst~, src1~, src2~)
                Jle => Jle(dst~, src1~, src2~)
                Jge => Jge(dst~, src1~, src2~)
                Jc => Jc(dst~)
                Jnc => Jnc(dst~)
                Jz => Jz(dst~)
                Jnz => Jnz(dst~)
                _ => impossible()
            })
        }
        Some(Push) => {
            self.advance()
            let val = self.expect_reg()
            Some(Push(val~))
        }
        Some(Pop) => {
            self.advance()
            let dst = self.expect_reg()
            Some(Pop(dst~))
        }
        Some(Call) => {
            self.advance()
            let dst = self.expect_label()
            Some(Call(dst~))
        }
        Some(Ret) => {
            self.advance()
            Some(Ret)
        }
        Some(Nop) => {
            self.advance()
            Some(Nop)
        }
        _ => None
    }
}

priv struct ParseResult {
    pseudo: Array[PseudoInst[Reg]]
    next_label_id: UInt
}

fn parse(tokens: Array[Token]) -> ParseResult raise ParserError {
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
    let pseudo_insts: Array[PseudoInst[Reg]] = []

    while parser.index < parser.tokens.length() {
        match parser.parse_inst() {
            Some(inst) => {
                pseudo_insts.push(inst)
            }
            None => break
        }
    }

    {
        pseudo: pseudo_insts,
        next_label_id: label_ids.size().reinterpret_as_uint(),
    }
}
