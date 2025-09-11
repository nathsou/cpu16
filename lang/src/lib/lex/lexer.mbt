
pub(all) struct Lexer {
    input: String
    mut index: Int
}

pub fn Lexer::new(input: String) -> Lexer {
    {
        input,
        index: 0,
    }
}

pub fn peek(self: Lexer) -> Char? {
    if self.index < self.input.length() {
        self.input[self.index].to_char()
    } else {
        None
    }
}

pub fn is_whitespace(c: Char) -> Bool {
    c == ' ' || c == '\n' || c == '\r' || c == '\t'
}

pub fn is_alpha(c: Char) -> Bool {
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

pub fn is_alphanumeric(c: Char) -> Bool {
    is_alpha(c) || is_digit(c, base=10)
}

pub fn is_identifier_start(c: Char) -> Bool {
    is_alpha(c) || c is ('_' | '$' | '@')
}

pub fn is_identifier_char(c: Char) -> Bool {
    is_alphanumeric(c) || c is ('_' | '$' | '@')
}

pub fn is_digit(c: Char, base~: UInt) -> Bool {
    match base {
        2 => c >= '0' && c <= '1'
        8 => c >= '0' && c <= '7'
        10 => c >= '0' && c <= '9'
        16 => (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
        _ => false
    }
}

pub fn parse_digit(c: Char, base~: UInt) -> UInt? {
    match c {
        '0' | '1' if base == 2 => Some(c.to_uint() - '0'.to_uint())
        '0'..='7' if base == 8 => Some(c.to_uint() - '8'.to_uint() + 8)
        '0'..='9' if base > 8 => Some(c.to_uint() - '0'.to_uint())
        'a'..='f' if base == 16 => Some(c.to_uint() - 'a'.to_uint() + 10)
        'A'..='F' if base == 16 => Some(c.to_uint() - 'A'.to_uint() + 10)
        _ => None
    }
}

pub fn parse_integer(self: Lexer) -> UInt {
    let mut value = 0U
    
    for i = self.index; i < self.input.length(); i = i + 1 {
        let c = self.input[i].to_char().unwrap()

        if is_digit(c, base=10) {
            value = value * 10U + parse_digit(c, base=10).unwrap()
            self.index += 1
        } else {
            break
        }
    }

    value
}

pub fn parse_identifier(self: Lexer) -> String {
    let identifier = StringBuilder::new()

    while true {
        match self.peek() {
            Some(c) => {
                if is_identifier_char(c) {
                    identifier.write_char(c)
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

    identifier.to_string()
}

pub fn matches(self: Lexer, char: Char) -> Bool {
    match self.peek() {
        Some(c) => c == char
        _ => false
    }
}

pub fn consumes(self: Lexer, char: Char) -> Bool {
    if self.matches(char) {
        self.index += 1
        true
    } else {
        false
    }
}

pub fn skip_whitespaces(self: Lexer) -> Unit {
    for i = self.index; i < self.input.length(); i = i + 1  {
        let c = self.input[i].to_char().unwrap()

        if is_whitespace(c) {
            self.index += 1
        } else {
            break
        }
    }
}

pub fn[T] collect(source: String, next_token: (Lexer) -> T? raise) -> Array[T] raise {
    let lexer = Lexer::new(source)
    let tokens = []

    while true {
        let token = next_token(lexer)

        match token {
            Some(t) => {
                tokens.push(t)
            }
            None => {
                break
            }
        }
    }

    tokens
}
