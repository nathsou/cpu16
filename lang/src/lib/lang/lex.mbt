pub enum Token {
    Lparen; Rparen; Lbrace; Rbrace; Comma; Semicolon; Colon; Dot
    Plus; Minus; Star; Slash; Percent; Caret
    Ampersand; AmpersandAmpersand; Pipe; PipePipe
    Bang; Equal; EqualEqual; BangEqual
    LeftChevron; RightChevron; LeftFatArrow; RightFatArrow
    U8; U16
    Fn; If; Else; Let; Var; While; Return
    True; False
    Identifier(String)
    Integer(Int, IntKind)
} derive(Show, Eq)

pub enum IntKind {
    U8
    U16
} derive (Show, Eq)

pub suberror LexerError String derive (Show)

pub fn next_token(lexer: @lex.Lexer) -> Token? raise {
    lexer.skip_whitespaces()

    match lexer.peek() {
        None => None
        Some(c) => match c {
            '(' => {
                lexer.index += 1
                Some(Lparen)
            }
            ')' => {
                lexer.index += 1
                Some(Rparen)
            }
            '{' => {
                lexer.index += 1
                Some(Lbrace)
            }
            '}' => {
                lexer.index += 1
                Some(Rbrace)
            }
            ',' => {
                lexer.index += 1
                Some(Comma)
            }
            ';' => {
                lexer.index += 1
                Some(Semicolon)
            }
            ':' => {
                lexer.index += 1
                Some(Colon)
            }
            '.' => {
                lexer.index += 1
                Some(Dot)
            }
            '+' => {
                lexer.index += 1
                Some(Plus)
            }
            '-' => {
                lexer.index += 1
                Some(Minus)
            }
            '*' => {
                lexer.index += 1
                Some(Star)
            }
            '/' => {
                lexer.index += 1
                Some(Slash)
            }
            '%' => {
                lexer.index += 1
                Some(Percent)
            }
            '^' => {
                lexer.index += 1
                Some(Caret)
            }
            '&' => {
                lexer.index += 1

                if lexer.consumes('&') {
                    Some(AmpersandAmpersand)
                } else {
                    Some(Ampersand)
                }
            }
            '|' => {
                lexer.index += 1
                
                if lexer.consumes('|') {
                    Some(PipePipe)
                } else {
                    Some(Pipe)
                }
            }
            '!' => {
                lexer.index += 1

                if lexer.consumes('=') {
                    Some(BangEqual)
                } else {
                    Some(Bang)
                }
            }
            '=' => {
                lexer.index += 1

                Some(if lexer.consumes('=') {
                        EqualEqual
                    } else if lexer.consumes('>') {
                        RightFatArrow
                    } else {
                        Equal
                })
            }
            '<' => {
                lexer.index += 1

                if lexer.consumes('=') {
                    Some(LeftFatArrow)
                } else {
                    Some(LeftChevron)
                }
            }
            '>' => {
                lexer.index += 1
                Some(RightChevron)
            }
            _ => {
                if @lex.is_digit(c, base=10) {
                    let value = lexer.parse_integer()
                    // Optional integer kind suffix: u8 (defaults to u16)
                    let saved_index = lexer.index
                    let kind = if lexer.consumes('u') {
                        if lexer.consumes('8') {
                            IntKind::U8
                        } else if lexer.consumes('1') {
                            if lexer.consumes('6') {
                                IntKind::U16
                            } else {
                                // rollback if not a proper suffix
                                lexer.index = saved_index
                                IntKind::U16
                            }
                        } else {
                            // rollback if not a proper suffix
                            lexer.index = saved_index
                            IntKind::U16
                        }
                    } else {
                        IntKind::U16
                    }

                    Some(Integer(value.reinterpret_as_int(), kind))
                } else if @lex.is_identifier_start(c) {
                    let identifier = lexer.parse_identifier()

                    Some(match identifier {
                        "let" => Let
                        "var" => Var
                        "fn" => Fn
                        "u16" => U16
                        "u8" => U8
                        "if" => If
                        "else" => Else
                        "true" => True
                        "false" => False
                        "while" => While
                        "return" => Return
                        _ => Identifier(identifier)
                    })
                } else {
                    raise LexerError("Unexpected character")
                }
            }
        }
    }
}
