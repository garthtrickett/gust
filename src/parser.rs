use crate::ast::{
    BlockStatement, Expression, FieldDef, MatchCase, Parameter, Program, Statement, VariantDef,
};
use crate::lexer::Lexer;
use crate::token::{Token, TokenType};
use crate::typechecker::Type;

pub struct Parser {
    lexer: Lexer,
    cur_token: Token,
    peek_token: Token,
    pushback_tokens: Vec<Token>,
}

impl Parser {
    pub fn new(mut lexer: Lexer) -> Self {
        let cur_token = lexer.next_token();
        let peek_token = lexer.next_token();
        Parser {
            lexer,
            cur_token,
            peek_token,
            pushback_tokens: Vec::new(),
        }
    }

    fn next_token(&mut self) {
        self.cur_token = self.peek_token.clone();
        if let Some(tok) = self.pushback_tokens.pop() {
            self.peek_token = tok;
        } else {
            self.peek_token = self.lexer.next_token();
        }
    }

    pub fn parse_program(&mut self) -> Program {
        let mut statements = Vec::new();

        while self.cur_token.token_type != TokenType::Eof {
            if let Some(stmt) = self.parse_statement() {
                statements.push(stmt);
            }
            if self.peek_token.token_type == TokenType::Semicolon {
                self.next_token();
            }
            self.next_token();
        }

        Program { statements }
    }

    fn parse_statement(&mut self) -> Option<Statement> {
        match self.cur_token.token_type {
            TokenType::Type => self.parse_struct_decl(),
            TokenType::Func => self.parse_function_decl(),
            TokenType::Mut => self.parse_var_decl(true),
            TokenType::Defer => self.parse_defer_statement(),
            TokenType::While => self.parse_while_statement(),
            TokenType::If => self.parse_if_statement(),
            TokenType::Unsafe => self.parse_unsafe_block(),
            TokenType::Return => self.parse_return_statement(),
            TokenType::Match => self.parse_match_statement(),
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

    fn parse_struct_decl(&mut self) -> Option<Statement> {
        self.next_token(); // consume 'type'
        if self.cur_token.token_type != TokenType::Ident {
            return None;
        }
        let name = self.cur_token.literal.clone();
        self.next_token();

        let mut generics = Vec::new();
        if self.cur_token.token_type == TokenType::LBracket {
            self.next_token(); // consume '['
            while self.cur_token.token_type == TokenType::Ident {
                generics.push(self.cur_token.literal.clone());
                self.next_token();
                if self.cur_token.token_type == TokenType::Comma {
                    self.next_token();
                }
            }
            if self.cur_token.token_type != TokenType::RBracket {
                return None;
            }
            self.next_token(); // consume ']'
        }

        if self.cur_token.token_type == TokenType::Struct {
            self.next_token();

            if self.cur_token.token_type != TokenType::LBrace {
                return None;
            }
            self.next_token();

            let mut fields = Vec::new();
            while self.cur_token.token_type != TokenType::RBrace
                && self.cur_token.token_type != TokenType::Eof
            {
                if self.cur_token.token_type == TokenType::Ident {
                    let field_name = self.cur_token.literal.clone();
                    self.next_token();

                    if self.cur_token.token_type != TokenType::Colon {
                        return None;
                    }
                    self.next_token();

                    let field_type = self.parse_type_signature()?;
                    fields.push(FieldDef {
                        name: field_name,
                        field_type,
                    });

                    if self.cur_token.token_type == TokenType::Comma
                        || self.cur_token.token_type == TokenType::Semicolon
                    {
                        self.next_token();
                    }
                } else {
                    self.next_token();
                }
            }

            if self.cur_token.token_type != TokenType::RBrace {
                return None;
            }

            Some(Statement::StructDecl {
                name,
                generics,
                fields,
            })
        } else if self.cur_token.token_type == TokenType::Enum {
            self.next_token(); // consume 'enum'

            if self.cur_token.token_type != TokenType::LBrace {
                return None;
            }
            self.next_token(); // consume '{'

            let mut variants = Vec::new();
            while self.cur_token.token_type != TokenType::RBrace
                && self.cur_token.token_type != TokenType::Eof
            {
                if self.cur_token.token_type == TokenType::Ident {
                    let variant_name = self.cur_token.literal.clone();
                    self.next_token();

                    let mut fields = Vec::new();
                    // Optional fields block: VariantName { field1: Type, ... }
                    if self.cur_token.token_type == TokenType::LBrace {
                        self.next_token(); // consume '{'
                        while self.cur_token.token_type != TokenType::RBrace
                            && self.cur_token.token_type != TokenType::Eof
                        {
                            if self.cur_token.token_type == TokenType::Ident {
                                let f_name = self.cur_token.literal.clone();
                                self.next_token();

                                if self.cur_token.token_type != TokenType::Colon {
                                    return None;
                                }
                                self.next_token();

                                let f_type = self.parse_type_signature()?;
                                fields.push(FieldDef {
                                    name: f_name,
                                    field_type: f_type,
                                });

                                if self.cur_token.token_type == TokenType::Comma
                                    || self.cur_token.token_type == TokenType::Semicolon
                                {
                                    self.next_token();
                                }
                            } else {
                                self.next_token();
                            }
                        }
                        if self.cur_token.token_type != TokenType::RBrace {
                            return None;
                        }
                        self.next_token(); // consume '}'
                    }

                    variants.push(VariantDef {
                        name: variant_name,
                        fields,
                    });

                    if self.cur_token.token_type == TokenType::Comma
                        || self.cur_token.token_type == TokenType::Semicolon
                    {
                        self.next_token();
                    }
                } else {
                    self.next_token();
                }
            }

            if self.cur_token.token_type != TokenType::RBrace {
                return None;
            }

            Some(Statement::EnumDecl {
                name,
                generics,
                variants,
            })
        } else {
            None
        }
    }

    fn parse_function_decl(&mut self) -> Option<Statement> {
        self.next_token(); // consume 'func'
        if self.cur_token.token_type != TokenType::Ident {
            return None;
        }
        let name = self.cur_token.literal.clone();
        self.next_token();

        if self.cur_token.token_type != TokenType::LParen {
            return None;
        }
        self.next_token(); // consume '('

        let mut params = Vec::new();
        while self.cur_token.token_type != TokenType::RParen
            && self.cur_token.token_type != TokenType::Eof
        {
            if self.cur_token.token_type != TokenType::Ident {
                return None;
            }
            let param_name = self.cur_token.literal.clone();
            self.next_token();

            if self.cur_token.token_type != TokenType::Colon {
                return None;
            }
            self.next_token(); // consume ':'

            let param_type = self.parse_type_signature()?;
            params.push(Parameter {
                name: param_name,
                param_type,
            });

            if self.cur_token.token_type == TokenType::Comma {
                self.next_token(); // consume ','
            }
        }

        if self.cur_token.token_type != TokenType::RParen {
            return None;
        }
        self.next_token(); // consume ')'

        // Parse optional return type
        let mut return_type = Type::Void;
        if self.cur_token.token_type == TokenType::Ident
            || self.cur_token.token_type == TokenType::LBracket
            || self.cur_token.token_type == TokenType::Asterisk
            || self.cur_token.token_type == TokenType::Ampersand
        {
            return_type = self.parse_type_signature()?;
        }

        if self.cur_token.token_type != TokenType::LBrace {
            return None;
        }

        let body = self.parse_block_statement()?;
        Some(Statement::FunctionDecl {
            name,
            params,
            return_type,
            body,
        })
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

        let mut value = None;
        if self.cur_token.token_type == TokenType::Assign {
            self.next_token();
            value = Some(self.parse_expression(1)?);
        }

        Some(Statement::VarDecl {
            name,
            is_mut,
            value,
            var_type,
        })
    }

    fn parse_type_signature(&mut self) -> Option<Type> {
        if self.cur_token.token_type == TokenType::Asterisk
            || self.cur_token.token_type == TokenType::Ampersand
        {
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
            let element_type = self.parse_type_signature()?;
            return Some(Type::Slice(Box::new(element_type)));
        }

        if self.cur_token.token_type != TokenType::Ident {
            return None;
        }
        let mut base_name = self.cur_token.literal.clone();
        self.next_token();

        while self.cur_token.token_type == TokenType::Dot {
            self.next_token(); // consume '.'
            if self.cur_token.token_type != TokenType::Ident {
                return None;
            }
            base_name.push('.');
            base_name.push_str(&self.cur_token.literal);
            self.next_token();
        }

        if self.cur_token.token_type == TokenType::LBracket {
            self.next_token(); // consume '['
            let mut args = Vec::new();

            if self.cur_token.token_type != TokenType::RBracket {
                args.push(self.parse_type_signature()?);
                while self.cur_token.token_type == TokenType::Comma {
                    self.next_token(); // consume ','
                    args.push(self.parse_type_signature()?);
                }
            }

            if self.cur_token.token_type != TokenType::RBracket {
                return None;
            }
            self.next_token(); // consume ']'

            // Backward-compatible Index matching
            if base_name == "Index" {
                if args.len() == 1 {
                    let brand = match &args[0] {
                        Type::Struct(name, _) => Some(name.clone()),
                        _ => None,
                    };
                    return Some(Type::Index("SessionNode".to_string(), brand));
                } else if args.len() == 2 {
                    let struct_name = match &args[0] {
                        Type::Struct(name, _) => name.clone(),
                        _ => "SessionNode".to_string(),
                    };
                    let brand = match &args[1] {
                        Type::Struct(name, _) => Some(name.clone()),
                        _ => None,
                    };
                    return Some(Type::Index(struct_name, brand));
                }
            }

            // Single parameter shorthand: Branded struct (e.g. SessionNode[connCtx])
            if args.len() == 1 {
                let brand = match &args[0] {
                    Type::Struct(name, _) => Some(name.clone()),
                    _ => None,
                };
                if let Some(brand_name) = &brand { 
                    if brand_name == "int" || brand_name == "byte" || brand_name == "str" || brand_name == "Arena" || brand_name == "os_Arena" {
                        return Some(Type::Generic(base_name, args));
                    }
                } else {
                    return Some(Type::Generic(base_name, args));
                }
                return Some(Type::Struct(base_name, brand));
            }

            // Multi-parameter instantiations: fully generic models (e.g. Vector[int, connCtx])
            return Some(Type::Generic(base_name, args));
        }

        match base_name.as_str() {
            "int" => Some(Type::Int),
            "byte" => Some(Type::Byte),
            "Arena" | "os_Arena" | "os.Arena" => Some(Type::Arena),
            "str" => Some(Type::Str),
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

    fn parse_match_statement(&mut self) -> Option<Statement> {
        self.next_token(); // consume 'match'
        let expression = self.parse_expression(1)?;

        self.next_token();
        if self.cur_token.token_type != TokenType::LBrace {
            return None;
        }
        self.next_token(); // consume '{'

        let mut cases = Vec::new();
        while self.cur_token.token_type != TokenType::RBrace
            && self.cur_token.token_type != TokenType::Eof
        {
            if self.cur_token.token_type != TokenType::Ident {
                return None;
            }
            let variant_name = self.cur_token.literal.clone();
            self.next_token();

            if self.cur_token.token_type != TokenType::FatArrow {
                return None;
            }
            self.next_token(); // consume '=>'

            if self.cur_token.token_type != TokenType::LBrace {
                return None;
            }
            let body = self.parse_block_statement()?;
            // parse_block_statement leaves cur_token at '}'
            self.next_token(); // consume '}'

            cases.push(MatchCase { variant_name, body });

            if self.cur_token.token_type == TokenType::Comma {
                self.next_token();
            }
        }

        if self.cur_token.token_type != TokenType::RBrace {
            return None;
        }

        Some(Statement::Match { expression, cases })
    }

    fn parse_unsafe_block(&mut self) -> Option<Statement> {
        self.next_token();
        if self.cur_token.token_type != TokenType::LBrace {
            return None;
        }
        let body = self.parse_block_statement()?;
        Some(Statement::UnsafeBlock { body })
    }

    fn parse_return_statement(&mut self) -> Option<Statement> {
        self.next_token(); // consume 'return'
        if self.cur_token.token_type == TokenType::Semicolon
            || self.cur_token.token_type == TokenType::RBrace
        {
            return Some(Statement::Return(None));
        }

        let expr = self.parse_expression(1)?;
        Some(Statement::Return(Some(expr)))
    }

    pub fn parse_expression(&mut self, precedence: i32) -> Option<Expression> {
        let mut left = self.parse_primary_expression()?;

        while precedence < self.peek_token_precedence() {
            if self.cur_token.token_type == TokenType::Semicolon {
                break;
            }
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

                    // Realign the token stream state with the Pratt parser loop expectations
                    let next_op = self.cur_token.clone();
                    let token_after = self.peek_token.clone();

                    self.pushback_tokens.push(token_after);
                    self.peek_token = next_op;
                    self.cur_token = Token {
                        token_type: TokenType::Illegal,
                        literal: "".to_string(),
                        span: Span::dummy(),
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
            TokenType::LParen => {
                self.next_token(); // consume '('
                let expr = self.parse_expression(1)?;
                if self.peek_token.token_type != TokenType::RParen {
                    return None;
                }
                self.next_token(); // consume ')'
                Some(expr)
            }
            TokenType::Ident => Some(Expression::Identifier(self.cur_token.literal.clone())),
            TokenType::Int => {
                let val: i64 = self.cur_token.literal.parse().ok()?;
                Some(Expression::Integer(val))
            }
            TokenType::String => Some(Expression::String(self.cur_token.literal.clone())),
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
            TokenType::Empty => {
                self.next_token(); // consume 'empty'
                if self.cur_token.token_type != TokenType::LBracket {
                    return None;
                }
                self.next_token(); // consume '['
                let target_type = self.parse_type_signature()?;
                if self.cur_token.token_type != TokenType::RBracket {
                    return None;
                }
                Some(Expression::Empty(target_type))
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

#[cfg(test)]
mod tests {
    use super::*;

    fn format_expr(expr: &Expression) -> String {
        match expr {
            Expression::Identifier(name) => name.clone(),
            Expression::Integer(val) => val.to_string(),
            Expression::String(val) => format!("\"{}\"", val),
            Expression::Move(inner) => format!("(move {})", format_expr(inner)),
            Expression::Take(inner) => format!("(take {})", format_expr(inner)),
            Expression::AddressOf(inner) => format!("(& {})", format_expr(inner)),
            Expression::Dereference(inner) => format!("(* {})", format_expr(inner)),
            Expression::IndexAccess { allocator, index } => {
                format!("{}[{}]", format_expr(allocator), format_expr(index))
            }
            Expression::AsCast {
                left,
                target_type,
                is_reference,
            } => {
                let ref_str = if *is_reference { "&" } else { "" };
                format!("({} as {}{:?})", format_expr(left), ref_str, target_type)
            }
            Expression::Binary { op, left, right } => {
                format!("({} {} {})", format_expr(left), op, format_expr(right))
            }
            Expression::Selector { left, right } => {
                format!("{}.{}", format_expr(left), right)
            }
            Expression::Call {
                function,
                arguments,
            } => {
                let args_strs: Vec<String> = arguments.iter().map(format_expr).collect();
                format!("{}({})", format_expr(function), args_strs.join(", "))
            }
            Expression::Empty(target_type) => {
                format!("(empty[{:?}])", target_type)
            }
        }
    }

    fn parse_expr_str(input: &str) -> Expression {
        let lexer = Lexer::new(input);
        let mut parser = Parser::new(lexer);
        parser
            .parse_expression(1)
            .expect("Failed to parse expression")
    }

    #[test]
    fn test_arithmetic_operator_precedence() {
        assert_eq!(format_expr(&parse_expr_str("a + b * c")), "(a + (b * c))");
        assert_eq!(format_expr(&parse_expr_str("a * b + c")), "((a * b) + c)");
        assert_eq!(format_expr(&parse_expr_str("a - b / c")), "(a - (b / c))");
        assert_eq!(
            format_expr(&parse_expr_str("a == b != c")),
            "((a == b) != c)"
        );
        assert_eq!(format_expr(&parse_expr_str("a < b > c")), "((a < b) > c)");
    }

    #[test]
    fn test_selector_and_call_precedence() {
        assert_eq!(format_expr(&parse_expr_str("a.b.c")), "a.b.c");
        assert_eq!(format_expr(&parse_expr_str("a.b(c)")), "a.b(c)");
        assert_eq!(format_expr(&parse_expr_str("a(b).c")), "a(b).c");
    }

    #[test]
    fn test_as_cast_precedence() {
        assert_eq!(
            format_expr(&parse_expr_str("a + b as int")),
            "(a + (b as Int))"
        );
        assert_eq!(
            format_expr(&parse_expr_str("a as int + b")),
            "((a as Int) + b)"
        );
    }

    #[test]
    fn test_index_access_precedence() {
        assert_eq!(format_expr(&parse_expr_str("a[b].c")), "a[b].c");
        assert_eq!(format_expr(&parse_expr_str("a.b[c]")), "a.b[c]");
        assert_eq!(format_expr(&parse_expr_str("a[b][c]")), "a[b][c]");
    }

    #[test]
    fn test_enum_and_match_parsing() {
        let input = "
            type Shape enum {
                Circle { radius: int },
                Rectangle { width: int, height: int },
                Point,
            }

            func process(shape: Shape) {
                match shape {
                    Circle => {
                        return 1;
                    }
                    Rectangle => {
                        return 2;
                    }
                    Point => {
                        return 3;
                    }
                }
            }
        ";
        let lexer = Lexer::new(input);
        let mut parser = Parser::new(lexer);
        let program = parser.parse_program();
        assert_eq!(program.statements.len(), 2);
    }

    #[test]
    fn test_empty_intrinsic_parsing() {
        let input_int = "empty[int]";
        let expr_int = parse_expr_str(input_int);
        assert!(matches!(expr_int, Expression::Empty(Type::Int, _)));

        let input_node = "empty[Node]";
        let expr_node = parse_expr_str(input_node);
        if let Expression::Empty(Type::Struct(name, None), _) = expr_node {
            assert_eq!(name, "Node");
        } else {
            panic!("Expected empty[Node] to parse into Empty(Type::Struct)");
        }

        let input_node_ctx = "empty[Node[ctx]]";
        let expr_node_ctx = parse_expr_str(input_node_ctx);
        if let Expression::Empty(Type::Struct(name, Some(brand)), _) = expr_node_ctx {
            assert_eq!(name, "Node");
            assert_eq!(brand, "ctx");
        } else {
            panic!("Expected empty[Node[ctx]] to parse into Empty(Type::Struct with brand)");
        }

        let input_namespaced = "empty[std.Vector[int, ctx]]";
        let expr_namespaced = parse_expr_str(input_namespaced);
        if let Expression::Empty(Type::Generic(name, args), _) = expr_namespaced {
            assert_eq!(name, "std.Vector");
            assert_eq!(args.len(), 2);
        } else {
            panic!("Expected empty[std.Vector[int, ctx]] to parse into Empty(Type::Generic)");
        }
    }

    #[test]
    fn test_parser_span_merging() {
        let expr = parse_expr_str("a + b * c");
        let span = expr.span();
        assert_eq!(span.start.offset, 0);
        assert_eq!(span.end.offset, 9);
    }
}

    fn parse_type_str(input: &str) -> Type {
        let lexer = Lexer::new(input);
        let mut parser = Parser::new(lexer);
        parser
            .parse_type_signature()
            .expect("Failed to parse type signature")
    }

    #[test]
    fn test_namespaced_type_signature_parsing() {
        let t1 = parse_type_str("std.Vector[int, ctx]");
        if let Type::Generic(name, args) = t1 {
            assert_eq!(name, "std.Vector");
            assert_eq!(args.len(), 2);
            assert_eq!(args[0], Type::Int);
            if let Type::Struct(brand, None) = &args[1] {
                assert_eq!(brand, "ctx");
            } else {
                panic!("Expected brand to be a struct");
            }
        } else {
            panic!("Expected Type::Generic");
        }

        let t2 = parse_type_str("os.Arena");
        assert_eq!(t2, Type::Arena);

        let t3 = parse_type_str("std.HashMap[int, str, ctx]");
        if let Type::Generic(name, args) = t3 {
            assert_eq!(name, "std.HashMap");
            assert_eq!(args.len(), 3);
            assert_eq!(args[0], Type::Int);
            assert_eq!(args[1], Type::Str);
            if let Type::Struct(brand, None) = &args[2] {
                assert_eq!(brand, "ctx");
            } else {
                panic!("Expected brand to be a struct");
            }
        } else {
            panic!("Expected Type::Generic");
        }
    }

    #[test]
    fn test_namespaced_statement_parsing() {
        let input = "mut v: std.Vector[int, ctx] := os.VectorNew(ctx); mut a: os.Arena := os.Arena.New();";
        let lexer = Lexer::new(input);
        let mut parser = Parser::new(lexer);
        let program = parser.parse_program();
        assert_eq!(program.statements.len(), 2);
    }
}
