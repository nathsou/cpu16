
pub enum Token {
    Reg(Reg)
    Const(value~: UInt16, base~: UInt)
    LabelDef(String)
    Label(String)
    Directive(String)
    Comment(String)
    Ctl; Set; Mem; Alu
    Setw
    Halt; Setz; Clrz; Setc; Clrc
    Load; Store
    Add; Sub; Adc; Sbc; Move; Cmp
    Inc; Dec; Inc2; Dec2
    And; Nand; Or; Xor
    Not; Not2
    Shl; Shr
    Jmp; Jeq; Jne; Jlt; Jgt; Jle; Jge
    Jc; Jnc; Jz; Jnz
    Push; Pop
    Call; Ret    
    Nop
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

                if lexer.peek() == Some(':') {
                    lexer.index += 1
                    return Some(LabelDef(identifier))
                }

                Some(match identifier {
                    "ctl" => Ctl
                    "set" => Set
                    "mem" => Mem
                    "alu" => Alu
                    "r0" | "z" => Reg(Reg::Z)
                    "r1" => Reg(Reg::R1)
                    "r2" => Reg(Reg::R2)
                    "r3" => Reg(Reg::R3)
                    "r4" => Reg(Reg::R4)
                    "r5" | "tmp" => Reg(Reg::TMP)
                    "r6" | "sp" => Reg(Reg::SP)
                    "r7" | "pc" => Reg(Reg::PC)
                    "setw" => Setw
                    "add" => Add
                    "sub" => Sub
                    "adc" => Adc
                    "sbc" => Sbc
                    "inc" => Inc
                    "dec" => Dec
                    "inc2" => Inc2
                    "dec2" => Dec2
                    "and" => And
                    "nand" => Nand
                    "or" => Or
                    "xor" => Xor
                    "not" => Not
                    "not2" => Not2
                    "shl" => Shl
                    "shr" => Shr
                    "jmp" => Jmp
                    "jeq" => Jeq
                    "jne" => Jne
                    "jlt" => Jlt
                    "jgt" => Jgt
                    "jle" => Jle
                    "jge" => Jge
                    "jc" => Jc
                    "jnc" => Jnc
                    "jz" => Jz
                    "jnz" => Jnz
                    "halt" => Halt
                    "setz" => Setz
                    "clrz" => Clrz
                    "setc" => Setc
                    "clrc" => Clrc
                    "load" => Load
                    "store" => Store
                    "move" => Move
                    "cmp" => Cmp
                    "push" => Push
                    "pop" => Pop
                    "call" => Call
                    "ret" => Ret
                    "nop" => Nop
                    _ => Label(identifier)
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
            '.' => {
                lexer.index += 1
                let start_index = lexer.index
                
                while true {
                    match lexer.peek() {
                        Some(c) if c is 'a'..='z' || c == '_' => {
                            lexer.index += 1
                        }
                        _ => break
                    }
                }

                let directive = lexer.input[start_index:lexer.index].to_string()
                Some(Token::Directive(directive))
            }
            _ => {
                raise AsmLexerError("unexpected character '\{c}' at position \{lexer.index}")
            }
        }
    }
}
