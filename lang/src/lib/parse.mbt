
pub struct Parser {
    tokens: Array[Token]
    mut index: Int
}

pub fn Parser::new(tokens: Array[Token]) -> Parser {
    {
        tokens,
        index: 0
    }
}

type! ParserError String derive (Show)

fn peek(self: Parser) -> Option[Token] {
    if self.index < self.tokens.length() {
        Some(self.tokens[self.index])
    } else {
        None
    }
}

fn advance(self: Parser) -> Unit {
    self.index += 1
}

fn expect(self: Parser, expected: Token) -> Unit!ParserError {
    match self.peek() {
        Some(token) => {
            if token == expected {
                self.advance()
            } else {
                raise ParserError("unexpected token")
            }
        }
        _ => {
            raise ParserError("unexpected end of input")
        }
    }
}

fn matches(self: Parser, expected: Token) -> Bool {
    match self.peek() {
        Some(token) => token == expected
        _ => false
    }
}

fn identifier(self: Parser) -> String!ParserError {
    match self.peek() {
        Some(Token::Identifier(ident)) => {
            self.advance()
            ident
        }
        _ => {
            raise ParserError("expected identifier")
        }
    }
}

// '(' <expr> ')' | <integer>
fn parse_primary_expr(self: Parser) -> Expr!ParserError {
    match self.peek() {
        Some(Token::Lparen) => {
            self.expect!(Token::Lparen)
            let expr = self.parse_expr!()
            self.expect!(Token::Rparen)
            expr
        }
        Some(Token::Integer(n)) => {
            self.advance()
            Expr::Const(Const::Integer(n))
        }
        _ => {
            raise ParserError("expected primary expression")
        }
    }
}

// !<unary> | <primary>
fn parse_unary_expr(self: Parser) -> Expr!ParserError {
    if self.matches(Token::Bang) {
        self.advance()
        let expr = self.parse_unary_expr!()
        Expr::UnaryOp(UnaryOp::Not, expr)
    } else {
        self.parse_primary_expr!()
    }
}

// <unary> ((+ | -) <unary>)*
fn parse_additive_expr(self: Parser) -> Expr!ParserError {
    let mut lhs = self.parse_unary_expr!()

    while true {
        let op = match self.peek() {
            Some(Token::Plus) => Some(BinaryOp::Add)
            Some(Token::Minus) => Some(BinaryOp::Sub)
            _ => None
        }

        match op {
            Some(op) => {
                self.advance()
                let rhs = self.parse_additive_expr!()
                lhs = Expr::BinaryOp(lhs, op, rhs)
            }
            _ => {
                break
            }
        }
    }

    lhs
}

// <additive> ((* | / | %) <additive>)*
fn parse_multiplicative_expr(self: Parser) -> Expr!ParserError {
    let mut lhs = self.parse_additive_expr!()

    while true {
        let op = match self.peek() {
            Some(Token::Star) => Some(BinaryOp::Mul)
            Some(Token::Slash) => Some(BinaryOp::Div)
            Some(Token::Percent) => Some(BinaryOp::Mod)
            _ => None
        }

        match op {
            Some(op) => {
                self.advance()
                let rhs = self.parse_additive_expr!()
                lhs = Expr::BinaryOp(lhs, op, rhs)
            }
            _ => {
                break
            }
        }
    }

    lhs
}

pub fn parse_expr(self: Parser) -> Expr!ParserError {
    self.parse_multiplicative_expr!()
}
