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
    Identifier(String)
    Integer(Int, IntKind)
} derive(Show, Eq)

pub enum IntKind {
    U8
    U16
} derive (Show, Eq)

struct Lexer {
    input: String
    mut index: Int
}

pub fn Lexer::new(input: String) -> Lexer {
    {
        input,
        index: 0,
    }
}

fn peek(self: Lexer) -> Option[Char] {
    if self.index < self.input.length() {
        Some(self.input[self.index])
    } else {
        None
    }
}

fn is_whitespace(c: Char) -> Bool {
    c == ' ' || c == '\n' || c == '\r' || c == '\t'
}

fn is_decimal_digit(c: Char) -> Bool {
    c >= '0' && c <= '9'
}

fn is_alpha(c: Char) -> Bool {
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

fn is_alphanumeric(c: Char) -> Bool {
    is_alpha(c) || is_decimal_digit(c)
}

fn is_identifier_start(c: Char) -> Bool {
    is_alpha(c) || c == '_'
}

let zero_ascii: Int = '0'.to_int()

fn parse_digit(char: Char) -> Int {
    char.to_int() - zero_ascii
}

fn parse_integer(self: Lexer) -> Int {
    let mut value = 0
    
    for i = self.index; i < self.input.length(); i = i + 1 {
        let c = self.input[i]

        if is_decimal_digit(c) {
            value = value * 10 + parse_digit(c)
            self.index += 1
        } else {
            break
        }
    }

    value
}

fn parse_identifier(self: Lexer) -> String {
    let mut identifier = ""

    while true {
        match self.peek() {
            Some(c) => {
                if is_alphanumeric(c) {
                    identifier += c.to_string()
                    self.index += 1
                } else {
                    break
                }
            }
            _ => {
                break
            }
        }
    }

    identifier
}

type! LexerError String derive (Show)

fn matches(self: Lexer, char: Char) -> Bool {
    match self.peek() {
        Some(c) => c == char
        _ => false
    }
}

fn consumes(self: Lexer, char: Char) -> Bool {
    if self.matches(char) {
        self.index += 1
        true
    } else {
        false
    }
}

pub fn next(self: Lexer) -> Option[Token]!LexerError {
    // skip whitespaces
    for i = self.index; i < self.input.length(); i = i + 1  {
        let c = self.input[i]

        if is_whitespace(c) {
            self.index += 1
        } else {
            break
        }
    }

    if self.index >= self.input.length() {
        return None
    }

    let c = self.input[self.index]

    match c {
        '(' => {
            self.index += 1
            Some(Token::Lparen)
        }
        ')' => {
            self.index += 1
            Some(Token::Rparen)
        }
        '{' => {
            self.index += 1
            Some(Token::Lbrace)
        }
        '}' => {
            self.index += 1
            Some(Token::Rbrace)
        }
        ',' => {
            self.index += 1
            Some(Token::Comma)
        }
        ';' => {
            self.index += 1
            Some(Token::Semicolon)
        }
        ':' => {
            self.index += 1
            Some(Token::Colon)
        }
        '.' => {
            self.index += 1
            Some(Token::Dot)
        }
        '+' => {
            self.index += 1
            Some(Token::Plus)
        }
        '-' => {
            self.index += 1
            Some(Token::Minus)
        }
        '*' => {
            self.index += 1
            Some(Token::Star)
        }
        '/' => {
            self.index += 1
            Some(Token::Slash)
        }
        '%' => {
            self.index += 1
            Some(Token::Percent)
        }
        '^' => {
            self.index += 1
            Some(Token::Caret)
        }
        '&' => {
            self.index += 1

            if self.consumes('&') {
                Some(Token::AmpersandAmpersand)
            } else {
                Some(Token::Ampersand)
            }
        }
        '|' => {
            self.index += 1
            
            if self.consumes('|') {
                Some(Token::PipePipe)
            } else {
                Some(Token::Pipe)
            }
        }
        '!' => {
            self.index += 1

            if self.consumes('=') {
                Some(Token::BangEqual)
            } else {
                Some(Token::Bang)
            }
        }
        '=' => {
            self.index += 1

            Some(if self.consumes('=') {
                    Token::EqualEqual
                } else if self.consumes('>') {
                    Token::RightFatArrow
                } else {
                    Token::Equal
             })
        }
        '<' => {
            self.index += 1

            if self.consumes('=') {
                Some(Token::LeftFatArrow)
            } else {
                Some(Token::LeftChevron)
            }
        }
        '>' => {
            self.index += 1
            Some(Token::RightChevron)
        }
        _ => {
            if is_decimal_digit(c) {
                let value = self.parse_integer()
                Some(Token::Integer(value, IntKind::U16))
            } else if is_identifier_start(c) {
                let identifier = self.parse_identifier()

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
                    _ => Token::Identifier(identifier)
                })
            } else {
                raise LexerError("Unexpected character")
            }
        }
    }
}
