use crate::ast::{BlockStatement, Expression, Program, Statement};
use crate::lexer::Lexer;
use crate::token::{Token, TokenType};
use crate::typechecker::Type;

pub struct Parser {
    lexer: Lexer,
    cur_token: Token,
    peek_token: Token,
}

impl Parser {
    pub fn new(mut lexer: Lexer) -> Self {
        let cur_token = lexer.next_token();
        let peek_token = lexer.next_token();
        Parser {
            lexer,
            cur_token,
            peek_token,
        }
    }

    fn next_token(&mut self) {
        self.cur_token = self.peek_token.clone();
        self.peek_token = self.lexer.next_token();
    }

    pub fn parse_program(&mut self) -> Program {
        let mut statements = Vec::new();

        while self.cur_token.token_type != TokenType::Eof {
            if let Some(stmt) = self.parse_statement() {
                statements.push(stmt);
            }
            // Consume optional statement-terminating semicolon
            if self.peek_token.token_type == TokenType::Semicolon {
                self.next_token();
            }
            self.next_token();
        }

        Program { statements }
    }

    fn parse_statement(&mut self) -> Option<Statement> {
        match self.cur_token.token_type {
            TokenType::Func => self.parse_function_decl(),
            TokenType::Mut => self.parse_var_decl(true),
            TokenType::Defer => self.parse_defer_statement(),
            TokenType::While => self.parse_while_statement(),
            TokenType::If => self.parse_if_statement(),
            TokenType::Unsafe => self.parse_unsafe_block(),
            TokenType::Ident if self.peek_token.token_type == TokenType::Assign => {
                self.parse_var_decl(false)
            }
            TokenType::Ident if self.peek_token.token_type == TokenType::Colon => {
                self.parse_var_decl(false)
            }
            _ => {
                let expr = self.parse_expression(1)?;
                if self.peek_token.token_type == TokenType::Eq {
                    self.next_token();
                    self.next_token();
                    let value = self.parse_expression(1)?;
                    Some(Statement::Assignment { left: expr, value })
                } else {
                    Some(Statement::Expression(expr))
                }
            }
        }
    }

    fn parse_function_decl(&mut self) -> Option<Statement> {
        self.next_token();
        if self.cur_token.token_type != TokenType::Ident {
            return None;
        }
        let name = self.cur_token.literal.clone();

        self.next_token();
        if self.cur_token.token_type != TokenType::LParen {
            return None;
        }

        self.next_token();
        if self.cur_token.token_type != TokenType::RParen {
            return None;
        }

        self.next_token();
        if self.cur_token.token_type != TokenType::LBrace {
            return None;
        }

        let body = self.parse_block_statement()?;
        Some(Statement::FunctionDecl { name, body })
    }

    fn parse_block_statement(&mut self) -> Option<BlockStatement> {
        let mut statements = Vec::new();
        self.next_token();

        while self.cur_token.token_type != TokenType::RBrace
            && self.cur_token.token_type != TokenType::Eof
        {
            if let Some(stmt) = self.parse_statement() {
                statements.push(stmt);
            }
            if self.peek_token.token_type == TokenType::Semicolon {
                self.next_token();
            }
            self.next_token();
        }

        Some(BlockStatement { statements })
    }

    fn parse_var_decl(&mut self, is_mut: bool) -> Option<Statement> {
        if is_mut {
            self.next_token();
        }

        if self.cur_token.token_type != TokenType::Ident {
            return None;
        }
        let name = self.cur_token.literal.clone();
        self.next_token();

        let mut var_type = None;
        if self.cur_token.token_type == TokenType::Colon {
            self.next_token();
            var_type = Some(self.parse_type_signature()?);
        }

        if self.cur_token.token_type != TokenType::Assign {
            return None;
        }

        self.next_token();
        let value = self.parse_expression(1)?;
        Some(Statement::VarDecl {
            name,
            is_mut,
            value,
            var_type,
        })
    }

    fn parse_type_signature(&mut self) -> Option<Type> {
        if self.cur_token.token_type == TokenType::Asterisk {
            self.next_token();
            let target = self.parse_type_signature()?;
            return Some(Type::RawPointer(Box::new(target)));
        }

        if self.cur_token.token_type == TokenType::LBracket {
            self.next_token();
            if self.cur_token.token_type != TokenType::RBracket {
                return None;
            }
            self.next_token();
            let slice_base = self.cur_token.literal.clone();
            self.next_token();

            if slice_base == "byte" {
                return Some(Type::ByteSlice);
            }
            return None;
        }

        let base_name = self.cur_token.literal.clone();
        self.next_token();

        if self.cur_token.token_type == TokenType::LBracket {
            self.next_token();
            let brand_name = self.cur_token.literal.clone();
            self.next_token();
            if self.cur_token.token_type != TokenType::RBracket {
                return None;
            }
            self.next_token();

            if base_name == "Index" {
                return Some(Type::Index("SessionNode".to_string(), Some(brand_name)));
            }
            return Some(Type::Struct(base_name, Some(brand_name)));
        }

        match base_name.as_str() {
            "int" => Some(Type::Int),
            "Arena" | "os_Arena" => Some(Type::Arena),
            _ => Some(Type::Struct(base_name, None)),
        }
    }

    fn parse_defer_statement(&mut self) -> Option<Statement> {
        self.next_token();
        let expr = self.parse_expression(1)?;
        Some(Statement::Defer { expr })
    }

    fn parse_while_statement(&mut self) -> Option<Statement> {
        self.next_token();
        let condition = self.parse_expression(1)?;

        self.next_token();
        if self.cur_token.token_type != TokenType::LBrace {
            return None;
        }

        let body = self.parse_block_statement()?;
        Some(Statement::While { condition, body })
    }

    fn parse_if_statement(&mut self) -> Option<Statement> {
        self.next_token();
        let condition = self.parse_expression(1)?;

        self.next_token();
        if self.cur_token.token_type != TokenType::LBrace {
            return None;
        }
        let consequence = self.parse_block_statement()?;

        let mut alternative = None;
        if self.peek_token.token_type == TokenType::Else {
            self.next_token();
            self.next_token();
            if self.cur_token.token_type != TokenType::LBrace {
                return None;
            }
            alternative = Some(self.parse_block_statement()?);
        }

        Some(Statement::If {
            condition,
            consequence,
            alternative,
        })
    }

    fn parse_unsafe_block(&mut self) -> Option<Statement> {
        self.next_token();
        if self.cur_token.token_type != TokenType::LBrace {
            return None;
        }
        let body = self.parse_block_statement()?;
        Some(Statement::UnsafeBlock { body })
    }

    pub fn parse_expression(&mut self, precedence: i32) -> Option<Expression> {
        let mut left = self.parse_primary_expression()?;

        while precedence < self.peek_token_precedence() {
            match self.peek_token.token_type {
                TokenType::Dot => {
                    self.next_token();
                    self.next_token();
                    let right = self.cur_token.literal.clone();
                    left = Expression::Selector {
                        left: Box::new(left),
                        right,
                    };
                }
                TokenType::LParen => {
                    self.next_token();
                    let args = self.parse_call_arguments()?;
                    left = Expression::Call {
                        function: Box::new(left),
                        arguments: args,
                    };
                }
                TokenType::LBracket => {
                    self.next_token();
                    self.next_token();
                    let index_expr = self.parse_expression(1)?;

                    if self.peek_token.token_type != TokenType::RBracket {
                        return None;
                    }
                    self.next_token();

                    left = Expression::IndexAccess {
                        allocator: Box::new(left),
                        index: Box::new(index_expr),
                    };
                }
                TokenType::As => {
                    self.next_token();
                    let mut is_reference = false;

                    if self.peek_token.token_type == TokenType::Ampersand {
                        self.next_token();
                        is_reference = true;
                    }

                    self.next_token();
                    let target_type = self.parse_type_signature()?;

                    left = Expression::AsCast {
                        left: Box::new(left),
                        target_type,
                        is_reference,
                    };
                }
                TokenType::Plus
                | TokenType::Minus
                | TokenType::Asterisk
                | TokenType::Slash
                | TokenType::EqEq
                | TokenType::NotEq
                | TokenType::Lt
                | TokenType::Gt => {
                    let op_str = self.peek_token.literal.clone();
                    let op_prec = self.peek_token_precedence();

                    self.next_token();
                    self.next_token();

                    let right = self.parse_expression(op_prec)?;
                    left = Expression::Binary {
                        op: op_str,
                        left: Box::new(left),
                        right: Box::new(right),
                    };
                }
                _ => break,
            }
        }

        Some(left)
    }

    fn parse_primary_expression(&mut self) -> Option<Expression> {
        match self.cur_token.token_type {
            TokenType::Ident => Some(Expression::Identifier(self.cur_token.literal.clone())),
            TokenType::Int => {
                let val: i64 = self.cur_token.literal.parse().ok()?;
                Some(Expression::Integer(val))
            }
            TokenType::Move => {
                self.next_token();
                let expr = self.parse_expression(6)?;
                Some(Expression::Move(Box::new(expr)))
            }
            TokenType::Take => {
                self.next_token();
                let expr = self.parse_expression(6)?;
                Some(Expression::Take(Box::new(expr)))
            }
            TokenType::Ampersand => {
                self.next_token();
                let expr = self.parse_expression(6)?;
                Some(Expression::AddressOf(Box::new(expr)))
            }
            TokenType::Asterisk => {
                self.next_token();
                let expr = self.parse_expression(6)?;
                Some(Expression::Dereference(Box::new(expr)))
            }
            _ => None,
        }
    }

    fn peek_token_precedence(&self) -> i32 {
        match self.peek_token.token_type {
            TokenType::EqEq | TokenType::NotEq => 2,
            TokenType::Lt | TokenType::Gt => 3,
            TokenType::Plus | TokenType::Minus => 4,
            TokenType::Asterisk | TokenType::Slash => 5,
            TokenType::As => 6,
            TokenType::Dot | TokenType::LParen | TokenType::LBracket => 7,
            _ => 1,
        }
    }

    fn parse_call_arguments(&mut self) -> Option<Vec<Expression>> {
        let mut args = Vec::new();

        if self.peek_token.token_type == TokenType::RParen {
            self.next_token();
            return Some(args);
        }

        self.next_token();
        args.push(self.parse_expression(1)?);

        while self.peek_token.token_type == TokenType::Comma {
            self.next_token();
            self.next_token();
            args.push(self.parse_expression(1)?);
        }

        if self.peek_token.token_type != TokenType::RParen {
            return None;
        }
        self.next_token();

        Some(args)
    }
}
