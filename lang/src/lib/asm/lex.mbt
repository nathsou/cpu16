
pub enum Token {
    Ctl; Set; Mem; Alu
    Reg(Reg)
    Const(value~: UInt16, base~: UInt)
    Label(String)
    Comment(String)
} derive (Show, Eq)

pub suberror AsmLexerError String derive (Show)

fn next_token(lexer: @lex.Lexer) -> Token? raise {
    lexer.skip_whitespaces()

    match lexer.peek() {
        None => None
        Some(c) => match c {
            '0'..='9' => {
                let base: UInt = match c {
                    '0' => {
                        lexer.index += 1
                        match lexer.peek() {
                            Some('x') => {
                                lexer.index += 1
                                16 // hexadecimal
                            }
                            Some('o') => {
                                lexer.index += 1
                                8 // octal
                            }
                            Some('b') => {
                                lexer.index += 1
                                2 // binary
                            }
                            _ => 10 // decimal
                        }
                    }
                    _ => 10 // decimal
                }

                let mut value: UInt = 0

                while true {
                    match lexer.peek() {
                        Some(d) => {
                            if d is ('0'..='9' | 'a'..='f')  {
                                match @lex.parse_digit(d, base~) {
                                    None => raise AsmLexerError("invalid digit '\{d}' in base \{base} at position \{lexer.index}")
                                    Some(digit) => {
                                        value = value * base + digit
                                        lexer.index += 1
                                    }
                                }
                            } else {
                                break
                            }
                        }
                        _ => break
                    }
                }

                if value > 0xFFFF || value < 0 {
                    raise AsmLexerError("value out of range: \{value}")
                }

                Some(Const(value=value.reinterpret_as_int().to_uint16(), base~))
            }
            'a'..='z' | '_' => {
                let identifier = lexer.parse_identifier()

                Some(match identifier {
                    "ctl" => Token::Ctl
                    "set" => Token::Set
                    "mem" => Token::Mem
                    "alu" => Token::Alu
                    "r0" | "z" => Token::Reg(Reg::Z)
                    "r1" => Token::Reg(Reg::R1)
                    "r2" => Token::Reg(Reg::R2)
                    "r3" => Token::Reg(Reg::R3)
                    "r4" => Token::Reg(Reg::R4)
                    "r5" | "tmp" => Token::Reg(Reg::R5)
                    "r6" | "sp" => Token::Reg(Reg::SP)
                    "r7" | "pc" => Token::Reg(Reg::PC)
                    _ => Token::Label(identifier)
                })
            }
            ';' => {
                lexer.index += 1
                let start_index = lexer.index
                
                while true {
                    match lexer.peek() {
                        Some(c) if c != '\n' => {
                            lexer.index += 1
                        }
                        _ => break
                    }
                }

                let comment = lexer.input[start_index:lexer.index].to_string()
                Some(Token::Comment(comment))
            }
            _ => {
                raise AsmLexerError("unexpected character '\{c}' at position \{lexer.index}")
            }
        }
    }
}
