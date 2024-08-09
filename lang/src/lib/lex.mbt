
pub enum Keyword {
    Fn
    U16
    U8
    If
    Else
} derive(Show)

pub enum Symbol {
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
    Pipe
    Bang
    Equal
} derive(Show)

enum Literal {
    Integer(Int)
} derive(Show)

pub enum Token {
    Keyword(Keyword)
    Symbol(Symbol)
    Identifier(String)
    Literal(Literal)
} derive(Show)

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

pub fn next(self: Lexer) -> Option[Token] {
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
                Some(Token::Symbol(Symbol::Lparen))
            }
            ')' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Rparen))
            }
            '{' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Lbrace))
            }
            '}' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Rbrace))
            }
            ',' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Comma))
            }
            ';' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Semicolon))
            }
            ':' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Colon))
            }
            '.' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Dot))
            }
            '+' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Plus))
            }
            '-' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Minus))
            }
            '*' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Star))
            }
            '/' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Slash))
            }
            '%' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Percent))
            }
            '^' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Caret))
            }
            '&' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Ampersand))
            }
            '|' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Pipe))
            }
            '!' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Bang))
            }
            '=' => {
                self.index += 1
                Some(Token::Symbol(Symbol::Equal))
            }
            _ => {
                if is_decimal_digit(c) {
                    let value = self.parse_integer()
                    Some(Token::Literal(Literal::Integer(value)))
                } else if is_identifier_start(c) {
                    let identifier = self.parse_identifier()

                    Some(match identifier {
                        "fn" => Token::Keyword(Keyword::Fn)
                        "u16" => Token::Keyword(Keyword::U16)
                        "u8" => Token::Keyword(Keyword::U8)
                        "if" => Token::Keyword(Keyword::If)
                        "else" => Token::Keyword(Keyword::Else)
                        _ => Token::Identifier(identifier)
                    })
                } else {
                    None
                }
            }
    }
}
