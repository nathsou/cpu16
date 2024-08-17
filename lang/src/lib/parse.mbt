
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
                raise ParserError("unexpected token: '\{token}', expected '\{expected}'")
            }
        }
        _ => {
            raise ParserError("Expected \{expected}, got <EOF>")
        }
    }
}

fn matches(self: Parser, expected: Token) -> Bool {
    match self.peek() {
        Some(token) => token == expected
        _ => false
    }
}

fn consumes(self: Parser, expected: Token) -> Bool {
    if self.matches(expected) {
        self.advance()
        true
    } else {
        false
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

pub fn parse_expr(self: Parser) -> Expr!ParserError {
    self.parse_if_expr!()
}

// if <expr> { <expr> } (else { <expr> })?
fn parse_if_expr(self: Parser) -> Expr!ParserError {
    if self.consumes(Token::If) {
        let cond = self.parse_expr!()
        self.expect!(Token::Lbrace)
        let then_expr = self.parse_expr!()
        self.expect!(Token::Rbrace)

        let else_expr = if self.consumes(Token::Else) {
            self.expect!(Token::Lbrace)
            let expr = self.parse_expr!()
            self.expect!(Token::Rbrace)
            Some(expr)
        } else {
            None
        }

        Expr::If(cond, then_expr, else_expr)
    } else {
        self.parse_logical_or!()
    }
}

// <logical_and> (|| <logical_and>)*
fn parse_logical_or(self: Parser) -> Expr!ParserError {
    let mut lhs = self.parse_logical_and!()

    while true {
        if self.consumes(Token::PipePipe) {
            let rhs = self.parse_logical_and!()
            lhs = Expr::BinaryOp(lhs, BinaryOp::Or, rhs)
        } else {
            break
        }
    }

    lhs
}

// <equality> (|| <equality>)*
fn parse_logical_and(self: Parser) -> Expr!ParserError {
    let mut lhs = self.parse_equality_expr!()

    while true {
        if self.consumes(Token::AmpersandAmpersand) {
            let rhs = self.parse_equality_expr!()
            lhs = Expr::BinaryOp(lhs, BinaryOp::And, rhs)
        } else {
            break
        }
    }

    lhs
}

// <comparison> (== | != <comparison>)*
fn parse_equality_expr(self: Parser) -> Expr!ParserError {
    let mut lhs = self.parse_comparison_expr!()

    while true {
        let op = match self.peek() {
            Some(Token::EqualEqual) => BinaryOp::Equ
            Some(Token::BangEqual) => BinaryOp::Neq
            _ => break
        }

        self.advance()
        let rhs = self.parse_comparison_expr!()
        lhs = Expr::BinaryOp(lhs, op, rhs)
    }

    lhs
}

// <additive> ((< | > | <= | >=) <additive>)*
fn parse_comparison_expr(self: Parser) -> Expr!ParserError {
    let mut lhs = self.parse_additive_expr!()

    while true {
        let op = match self.peek() {
            Some(Token::LeftChevron) => BinaryOp::Lss
            Some(Token::RightChevron) => BinaryOp::Gtr
            Some(Token::LeftFatArrow) => BinaryOp::Leq
            Some(Token::RightFatArrow) => BinaryOp::Geq
            _ => break
        }

        self.advance()
        let rhs = self.parse_additive_expr!()
        lhs = Expr::BinaryOp(lhs, op, rhs)
    }

    lhs
}

// <unary> ((+ | -) <unary>)*
fn parse_additive_expr(self: Parser) -> Expr!ParserError {
    let mut lhs = self.parse_multiplicative_expr!()

    while true {
        let op = match self.peek() {
            Some(Token::Plus) => BinaryOp::Add
            Some(Token::Minus) => BinaryOp::Sub
            _ => break
        }

        self.advance()
        let rhs = self.parse_multiplicative_expr!()
        lhs = Expr::BinaryOp(lhs, op, rhs)
    }

    lhs
}

// <additive> ((* | / | %) <additive>)*
fn parse_multiplicative_expr(self: Parser) -> Expr!ParserError {
    let mut lhs = self.parse_unary_expr!()

    while true {
        let op = match self.peek() {
            Some(Token::Star) => BinaryOp::Mul
            Some(Token::Slash) => BinaryOp::Div
            Some(Token::Percent) => BinaryOp::Mod
            _ => break
        }

        self.advance()
        let rhs = self.parse_unary_expr!()
        lhs = Expr::BinaryOp(lhs, op, rhs)
    }

    lhs
}

// !<unary> | <primary>
fn parse_unary_expr(self: Parser) -> Expr!ParserError {
    if self.consumes(Token::Bang) {
        let expr = self.parse_unary_expr!()
        Expr::UnaryOp(UnaryOp::Not, expr)
    } else {
        self.parse_primary_expr!()
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
        Some(Token::Integer(n, kind)) => {
            self.advance()
            Expr::Const(Const::Integer(n, kind))
        }
        Some(Token::True) => {
            self.advance()
            Expr::Const(Const::Boolean(true))
        }
        Some(Token::False) => {
            self.advance()
            Expr::Const(Const::Boolean(false))
        }
        Some(Token::Identifier(name)) => {
            self.advance()
            Expr::Var(name)
        }
        Some(token) => {
            raise ParserError("Expected primary expression, got '\{token}'")
        }
        _ => {
            raise ParserError("Expected primary expression, got <EOF>")
        }
    }
}

pub fn parse_stmt(self: Parser) -> Stmt!ParserError {
    match self.peek() {
        Some(Token::Let) => {
            self.advance()
            self.parse_let_stmt!(~mutable=false)
        }
        Some(Token::Var) => {
            self.advance()
            self.parse_let_stmt!(~mutable=true)
        }
        Some(Token::While) => {
            self.advance()
            self.parse_while_stmt!()
        }
        _ => self.parse_assignment_stmt!()
    }
}

pub fn parse_stmts(self: Parser) -> Array[Stmt]!ParserError {
    let stmts = []

    while self.index < self.tokens.length() {
        stmts.push(self.parse_stmt!())
    }

    stmts
}

fn parse_assignment_stmt(self: Parser) -> Stmt!ParserError {
    let lhs = self.parse_expr!()
    
    match self.peek() {
        Some(Token::Equal) => {
            self.advance()
            let rhs = self.parse_expr!()
            self.expect!(Token::Semicolon)
            Stmt::Assign(~lhs, ~rhs)
        }
        Some(Token::Semicolon) => {
            self.advance()
            Stmt::Semi(lhs)
        }
        _ => {
            raise ParserError("expected assignment or expression statement")
        }
    }
}

fn parse_let_stmt(self: Parser, ~mutable: Bool) -> Stmt!ParserError {
    let name = self.identifier!()
    self.expect!(Token::Equal)
    let value = self.parse_expr!()
    self.expect!(Token::Semicolon)
    Stmt::Let(~name, ~mutable, ~value)
}

fn parse_while_stmt(self: Parser) -> Stmt!ParserError {
    let cond = self.parse_expr!()
    self.expect!(Token::Lbrace)

    let body = []
    while self.peek() != Some(Token::Rbrace) {
        let stmt = self.parse_stmt!()
        body.push(stmt)
    }
    
    self.expect!(Token::Rbrace)
    Stmt::While(~cond, ~body)
}
