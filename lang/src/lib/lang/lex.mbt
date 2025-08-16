pub enum Token {
    Lparen
    Rparen
    Lbrace
    Rbrace
    Comma
    Semicolon
    Colon
    Dot
    Plus
    Minus
    Star
    Slash
    Percent
    Caret
    Ampersand
    AmpersandAmpersand
    Pipe
    PipePipe
    Bang
    Equal
    EqualEqual
    BangEqual
    LeftChevron
    RightChevron
    LeftFatArrow
    RightFatArrow
    Fn
    U16
    U8
    If
    Else
    Let
    Var
    While
    True
    False
    Return
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
                Some(Token::Lparen)
            }
            ')' => {
                lexer.index += 1
                Some(Token::Rparen)
            }
            '{' => {
                lexer.index += 1
                Some(Token::Lbrace)
            }
            '}' => {
                lexer.index += 1
                Some(Token::Rbrace)
            }
            ',' => {
                lexer.index += 1
                Some(Token::Comma)
            }
            ';' => {
                lexer.index += 1
                Some(Token::Semicolon)
            }
            ':' => {
                lexer.index += 1
                Some(Token::Colon)
            }
            '.' => {
                lexer.index += 1
                Some(Token::Dot)
            }
            '+' => {
                lexer.index += 1
                Some(Token::Plus)
            }
            '-' => {
                lexer.index += 1
                Some(Token::Minus)
            }
            '*' => {
                lexer.index += 1
                Some(Token::Star)
            }
            '/' => {
                lexer.index += 1
                Some(Token::Slash)
            }
            '%' => {
                lexer.index += 1
                Some(Token::Percent)
            }
            '^' => {
                lexer.index += 1
                Some(Token::Caret)
            }
            '&' => {
                lexer.index += 1

                if lexer.consumes('&') {
                    Some(Token::AmpersandAmpersand)
                } else {
                    Some(Token::Ampersand)
                }
            }
            '|' => {
                lexer.index += 1
                
                if lexer.consumes('|') {
                    Some(Token::PipePipe)
                } else {
                    Some(Token::Pipe)
                }
            }
            '!' => {
                lexer.index += 1

                if lexer.consumes('=') {
                    Some(Token::BangEqual)
                } else {
                    Some(Token::Bang)
                }
            }
            '=' => {
                lexer.index += 1

                Some(if lexer.consumes('=') {
                        Token::EqualEqual
                    } else if lexer.consumes('>') {
                        Token::RightFatArrow
                    } else {
                        Token::Equal
                })
            }
            '<' => {
                lexer.index += 1

                if lexer.consumes('=') {
                    Some(Token::LeftFatArrow)
                } else {
                    Some(Token::LeftChevron)
                }
            }
            '>' => {
                lexer.index += 1
                Some(Token::RightChevron)
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

                    Some(Token::Integer(value.reinterpret_as_int(), kind))
                } else if @lex.is_identifier_start(c) {
                    let identifier = lexer.parse_identifier()

                    Some(match identifier {
                        "let" => Token::Let
                        "var" => Token::Var
                        "fn" => Token::Fn
                        "u16" => Token::U16
                        "u8" => Token::U8
                        "if" => Token::If
                        "else" => Token::Else
                        "true" => Token::True
                        "false" => Token::False
                        "while" => Token::While
                        "return" => Token::Return
                        _ => Token::Identifier(identifier)
                    })
                } else {
                    raise LexerError("Unexpected character")
                }
            }
        }
    }
}
