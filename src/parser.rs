use crate::ast::{
    BlockStatement, Expression, FieldDef, MatchCase, Parameter, Program, Statement, VariantDef,
};
use crate::lexer::Lexer;
use crate::token::{Span, Token, TokenType};
use crate::typechecker::{Type, TypeError, TypeErrorKind};

pub struct Parser {
    lexer: Lexer,
    cur_token: Token,
    peek_token: Token,
    pushback_tokens: Vec<Token>,
    pub errors: Vec<TypeError>,
    has_non_import_statement: bool,
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
            errors: Vec::new(),
            has_non_import_statement: false,
        }
    }

    fn get_type_ident(&self, t: &Type) -> String {
        let base = match t {
            Type::Int => "int".to_string(),
            Type::Byte => "byte".to_string(),
            Type::Bool => "bool".to_string(),
            Type::Arena => "Arena".to_string(),
            Type::Void => "void".to_string(),
            Type::Str => "str".to_string(),
            Type::ByteSlice => "ByteSlice".to_string(),
            Type::RawPointer(inner) => format!("{}_ptr", self.get_type_ident(inner)),
            Type::Slice(inner) => format!("Slice_{}", self.get_type_ident(inner)),
            Type::Struct(name, _) => name.clone(),
            Type::Index(name, _) => format!("Index_{}", name),
            Type::Generic(name, args) => self.get_monomorphized_name(name, args),
        };
        base.replace(".", "_")
    }

    fn get_monomorphized_name(&self, template_name: &str, args: &[Type]) -> String {
        let arg_names: Vec<String> = args.iter().map(|arg| self.get_type_ident(arg)).collect();
        let name = format!("{}_{}", template_name, arg_names.join("_"));
        name.replace(".", "_")
    }

    pub fn error_at_current(&mut self, message: String) {
        self.errors.push(TypeError {
            kind: TypeErrorKind::SyntaxError,
            message,
            span: Some(self.cur_token.span),
        });
    }

    pub fn synchronize(&mut self) {
        while self.cur_token.token_type != TokenType::Eof {
            match self.cur_token.token_type {
                TokenType::Semicolon => {
                    self.next_token(); // consume the semicolon
                    return;
                }
                TokenType::RBrace => {
                    // Stop *at* closing brace so the enclosing block parser can see and handle it
                    return;
                }
                TokenType::Func
                | TokenType::Type
                | TokenType::Mut
                | TokenType::While
                | TokenType::If
                | TokenType::Return
                | TokenType::Match
                | TokenType::Defer
                | TokenType::Unsafe
                | TokenType::Guard => {
                    // Stop *at* top-level or statement-starting keywords so they can be parsed as the next statement
                    return;
                }
                _ => {
                    self.next_token();
                }
            }
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

    fn merge_spans(&self, start: Span, end: Span) -> Span {
        Span {
            start: start.start,
            end: end.end,
        }
    }

    pub fn parse_program(&mut self) -> Program {
        let mut statements = Vec::new();
        let start_pos = self.cur_token.span.start;

        while self.cur_token.token_type != TokenType::Eof {
            let before_errors = self.errors.len();
            if let Some(stmt) = self.parse_statement() {
                statements.push(stmt);
                if self.peek_token.token_type == TokenType::Semicolon {
                    self.next_token();
                }
                self.next_token();
            } else {
                if self.errors.len() == before_errors {
                    self.error_at_current(
                        "Syntax Error: unexpected token or malformed statement".to_string(),
                    );
                }
                let before_sync = self.cur_token.token_type.clone();
                self.synchronize();
                if self.cur_token.token_type == before_sync {
                    self.next_token();
                }
            }
        }

        let end_pos = self.cur_token.span.end;
        Program {
            statements,
            span: Span {
                start: start_pos,
                end: end_pos,
            },
        }
    }

    fn parse_statement(&mut self) -> Option<Statement> {
        match self.cur_token.token_type {
            TokenType::Import => self.parse_import_statement(),
            TokenType::Type => {
                self.has_non_import_statement = true;
                self.parse_struct_decl()
            }
            TokenType::Func => {
                self.has_non_import_statement = true;
                self.parse_function_decl()
            }
            TokenType::Mut => {
                self.has_non_import_statement = true;
                self.parse_var_decl(true)
            }
            TokenType::Defer => {
                self.has_non_import_statement = true;
                self.parse_defer_statement()
            }
            TokenType::Guard => {
                self.has_non_import_statement = true;
                self.parse_guard_statement()
            }
            TokenType::While => {
                self.has_non_import_statement = true;
                self.parse_while_statement()
            }
            TokenType::If => {
                self.has_non_import_statement = true;
                self.parse_if_statement()
            }
            TokenType::Unsafe => {
                self.has_non_import_statement = true;
                self.parse_unsafe_block()
            }
            TokenType::Return => {
                self.has_non_import_statement = true;
                self.parse_return_statement()
            }
            TokenType::Match => {
                self.has_non_import_statement = true;
                self.parse_match_statement()
            }
            TokenType::Ident if self.peek_token.token_type == TokenType::Assign => {
                self.has_non_import_statement = true;
                self.parse_var_decl(false)
            }
            TokenType::Ident if self.peek_token.token_type == TokenType::Colon => {
                self.has_non_import_statement = true;
                self.parse_var_decl(false)
            }
            _ => {
                self.has_non_import_statement = true;
                let expr = self.parse_expression(1)?;
                if self.peek_token.token_type == TokenType::Eq {
                    self.next_token();
                    self.next_token();
                    let value = self.parse_expression(1)?;
                    let start_span = expr.span();
                    let end_span = value.span();
                    Some(Statement::Assignment {
                        left: expr,
                        value,
                        span: self.merge_spans(start_span, end_span),
                    })
                } else {
                    let span = expr.span();
                    Some(Statement::Expression(expr, span))
                }
            }
        }
    }

    fn parse_import_statement(&mut self) -> Option<Statement> {
        let start_span = self.cur_token.span;

        if self.has_non_import_statement {
            self.error_at_current(
                "Syntax Error: Imports must be at the beginning of the program".to_string(),
            );
        }

        self.next_token(); // consume 'import'

        if self.cur_token.token_type != TokenType::String {
            self.error_at_current("Expected string literal specifying the import path".to_string());
            return None;
        }
        let path = self.cur_token.literal.clone();
        self.next_token(); // consume path string

        let mut alias = None;
        if self.cur_token.token_type == TokenType::As {
            self.next_token(); // consume 'as'
            if self.cur_token.token_type != TokenType::Ident {
                self.error_at_current("Expected identifier alias after 'as'".to_string());
                return None;
            }
            alias = Some(self.cur_token.literal.clone());
            self.next_token(); // consume alias identifier
        }

        let end_span = self.cur_token.span;
        tracing::debug!(
            "📥 Parsed Import Statement: Path '{}', Alias: '{:?}'",
            path,
            alias
        );
        Some(Statement::Import {
            path,
            alias,
            span: self.merge_spans(start_span, end_span),
        })
    }

    fn parse_struct_decl(&mut self) -> Option<Statement> {
        let start_span = self.cur_token.span;
        self.next_token(); // consume 'type'
        if self.cur_token.token_type != TokenType::Ident {
            self.error_at_current("Expected identifier after 'type'".to_string());
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
                self.error_at_current(
                    "Expected closing bracket ']' in generic type parameters".to_string(),
                );
                return None;
            }
            self.next_token(); // consume ']'
        }

        if self.cur_token.token_type == TokenType::Struct {
            self.next_token();

            if self.cur_token.token_type != TokenType::LBrace {
                self.error_at_current("Expected opening brace '{' after 'struct'".to_string());
                return None;
            }
            self.next_token();

            let mut fields = Vec::new();
            while self.cur_token.token_type != TokenType::RBrace
                && self.cur_token.token_type != TokenType::Eof
            {
                if self.cur_token.token_type == TokenType::Ident {
                    let field_start = self.cur_token.span;
                    let field_name = self.cur_token.literal.clone();
                    self.next_token();

                    if self.cur_token.token_type != TokenType::Colon {
                        self.error_at_current(
                            "Expected ':' after struct field identifier".to_string(),
                        );
                        return None;
                    }
                    self.next_token();

                    let field_type = if let Some(t) = self.parse_type_signature() {
                        t
                    } else {
                        self.error_at_current("Expected field type signature".to_string());
                        return None;
                    };
                    let field_end = self.cur_token.span;
                    fields.push(FieldDef {
                        name: field_name,
                        field_type,
                        span: self.merge_spans(field_start, field_end),
                    });

                    if self.cur_token.token_type == TokenType::Comma
                        || self.cur_token.token_type == TokenType::Semicolon
                    {
                        self.next_token();
                    }
                } else {
                    self.error_at_current("Expected struct field identifier or '}'".to_string());
                    return None;
                }
            }

            if self.cur_token.token_type != TokenType::RBrace {
                self.error_at_current("Expected closing brace '}' after struct fields".to_string());
                return None;
            }
            let end_span = self.cur_token.span;

            Some(Statement::StructDecl {
                name,
                generics,
                fields,
                span: self.merge_spans(start_span, end_span),
            })
        } else if self.cur_token.token_type == TokenType::Enum {
            self.next_token(); // consume 'enum'

            if self.cur_token.token_type != TokenType::LBrace {
                self.error_at_current("Expected opening brace '{' after 'enum'".to_string());
                return None;
            }
            self.next_token(); // consume '{'

            let mut variants = Vec::new();
            while self.cur_token.token_type != TokenType::RBrace
                && self.cur_token.token_type != TokenType::Eof
            {
                if self.cur_token.token_type == TokenType::Ident {
                    let variant_start = self.cur_token.span;
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
                                let f_start = self.cur_token.span;
                                let f_name = self.cur_token.literal.clone();
                                self.next_token();

                                if self.cur_token.token_type != TokenType::Colon {
                                    self.error_at_current(
                                        "Expected ':' after enum variant field identifier"
                                            .to_string(),
                                    );
                                    return None;
                                }
                                self.next_token();

                                let f_type = if let Some(t) = self.parse_type_signature() {
                                    t
                                } else {
                                    self.error_at_current(
                                        "Expected field type signature".to_string(),
                                    );
                                    return None;
                                };
                                let f_end = self.cur_token.span;
                                fields.push(FieldDef {
                                    name: f_name,
                                    field_type: f_type,
                                    span: self.merge_spans(f_start, f_end),
                                });

                                if self.cur_token.token_type == TokenType::Comma
                                    || self.cur_token.token_type == TokenType::Semicolon
                                {
                                    self.next_token();
                                }
                            } else {
                                self.error_at_current(
                                    "Expected enum variant field identifier or '}'".to_string(),
                                );
                                return None;
                            }
                        }
                        if self.cur_token.token_type != TokenType::RBrace {
                            self.error_at_current(
                                "Expected closing brace '}' after enum variant fields".to_string(),
                            );
                            return None;
                        }
                        self.next_token(); // consume '}'
                    }
                    let variant_end = self.cur_token.span;

                    variants.push(VariantDef {
                        name: variant_name,
                        fields,
                        span: self.merge_spans(variant_start, variant_end),
                    });

                    if self.cur_token.token_type == TokenType::Comma
                        || self.cur_token.token_type == TokenType::Semicolon
                    {
                        self.next_token();
                    }
                } else {
                    self.error_at_current("Expected enum variant identifier or '}'".to_string());
                    return None;
                }
            }

            if self.cur_token.token_type != TokenType::RBrace {
                self.error_at_current("Expected closing brace '}' after enum variants".to_string());
                return None;
            }
            let end_span = self.cur_token.span;

            Some(Statement::EnumDecl {
                name,
                generics,
                variants,
                span: self.merge_spans(start_span, end_span),
            })
        } else {
            self.error_at_current("Expected 'struct' or 'enum' declaration".to_string());
            None
        }
    }

    fn parse_function_decl(&mut self) -> Option<Statement> {
        let start_span = self.cur_token.span;
        self.next_token(); // consume 'func'
        if self.cur_token.token_type != TokenType::Ident {
            self.error_at_current("Expected identifier after 'func'".to_string());
            return None;
        }
        let name = self.cur_token.literal.clone();
        self.next_token();

        if self.cur_token.token_type != TokenType::LParen {
            self.error_at_current("Expected '(' after function name".to_string());
            return None;
        }
        self.next_token(); // consume '('

        let mut params = Vec::new();
        while self.cur_token.token_type != TokenType::RParen
            && self.cur_token.token_type != TokenType::Eof
        {
            if self.cur_token.token_type != TokenType::Ident {
                self.error_at_current("Expected parameter name identifier".to_string());
                return None;
            }
            let param_start = self.cur_token.span;
            let param_name = self.cur_token.literal.clone();
            self.next_token();

            if self.cur_token.token_type != TokenType::Colon {
                self.error_at_current("Expected ':' after parameter name".to_string());
                return None;
            }
            self.next_token(); // consume ':'

            let param_type = if let Some(t) = self.parse_type_signature() {
                t
            } else {
                self.error_at_current("Expected parameter type signature".to_string());
                return None;
            };
            let param_end = self.cur_token.span;
            params.push(Parameter {
                name: param_name,
                param_type,
                span: self.merge_spans(param_start, param_end),
            });

            if self.cur_token.token_type == TokenType::Comma {
                self.next_token(); // consume ','
            }
        }

        if self.cur_token.token_type != TokenType::RParen {
            self.error_at_current("Expected closing parenthesis ')'".to_string());
            return None;
        }
        self.next_token(); // consume ')'

        // Parse optional return type
        let mut return_type = Type::Void;
        if self.cur_token.token_type == TokenType::Ident
            || self.cur_token.token_type == TokenType::Bool
            || self.cur_token.token_type == TokenType::LBracket
            || self.cur_token.token_type == TokenType::Asterisk
            || self.cur_token.token_type == TokenType::Ampersand
        {
            return_type = if let Some(t) = self.parse_type_signature() {
                t
            } else {
                self.error_at_current("Expected return type signature".to_string());
                return None;
            };
        }

        if self.cur_token.token_type != TokenType::LBrace {
            self.error_at_current("Expected opening brace '{' for function body".to_string());
            return None;
        }

        let body = self.parse_block_statement()?;
        let end_span = body.span;
        Some(Statement::FunctionDecl {
            name,
            params,
            return_type,
            body,
            span: self.merge_spans(start_span, end_span),
        })
    }

    fn parse_block_statement(&mut self) -> Option<BlockStatement> {
        let start_span = self.cur_token.span;
        let mut statements = Vec::new();
        self.next_token();

        while self.cur_token.token_type != TokenType::RBrace
            && self.cur_token.token_type != TokenType::Eof
        {
            let before_errors = self.errors.len();
            if let Some(stmt) = self.parse_statement() {
                statements.push(stmt);
                if self.peek_token.token_type == TokenType::Semicolon {
                    self.next_token();
                }
                self.next_token();
            } else {
                if self.errors.len() == before_errors {
                    self.error_at_current("Expected valid statement inside block".to_string());
                }
                self.synchronize();
            }
        }

        if self.cur_token.token_type != TokenType::RBrace {
            self.error_at_current("Expected closing brace '}'".to_string());
            return None;
        }
        let end_span = self.cur_token.span;
        Some(BlockStatement {
            statements,
            span: self.merge_spans(start_span, end_span),
        })
    }

    fn parse_var_decl(&mut self, is_mut: bool) -> Option<Statement> {
        let start_span = self.cur_token.span;
        if is_mut {
            self.next_token();
        }

        if self.cur_token.token_type != TokenType::Ident {
            self.error_at_current("Expected variable name identifier".to_string());
            return None;
        }
        let name = self.cur_token.literal.clone();
        self.next_token();

        let mut var_type = None;
        if self.cur_token.token_type == TokenType::Colon {
            self.next_token();
            let parsed_type = self.parse_type_signature();
            if parsed_type.is_none() {
                self.error_at_current("Expected type signature after ':'".to_string());
                return None;
            }
            var_type = parsed_type;
        }

        let mut value = None;
        if self.cur_token.token_type == TokenType::Assign {
            self.next_token();
            let parsed_expr = self.parse_expression(1);
            if parsed_expr.is_none() {
                self.error_at_current("Expected expression after ':='".to_string());
                return None;
            }
            value = parsed_expr;
        }

        let end_span = if let Some(ref val) = value {
            val.span()
        } else {
            self.cur_token.span
        };

        Some(Statement::VarDecl {
            name,
            is_mut,
            value,
            var_type,
            span: self.merge_spans(start_span, end_span),
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

        if self.cur_token.token_type != TokenType::Ident
            && self.cur_token.token_type != TokenType::Bool
        {
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
                        Type::Str => "str".to_string(),
                        Type::Int => "int".to_string(),
                        Type::Byte => "byte".to_string(),
                        Type::Bool => "bool".to_string(),
                        Type::Arena => "Arena".to_string(),
                        Type::Generic(name, generic_args) => {
                            self.get_monomorphized_name(name, generic_args)
                        }
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
                    if brand_name == "int"
                        || brand_name == "byte"
                        || brand_name == "str"
                        || brand_name == "Arena"
                        || brand_name == "os_Arena"
                    {
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
            "bool" => Some(Type::Bool),
            "Arena" | "os_Arena" | "os.Arena" => Some(Type::Arena),
            "str" => Some(Type::Str),
            _ => Some(Type::Struct(base_name, None)),
        }
    }

    fn parse_defer_statement(&mut self) -> Option<Statement> {
        let start_span = self.cur_token.span;
        self.next_token();
        let expr = self.parse_expression(1)?;
        let end_span = expr.span();
        Some(Statement::Defer {
            expr,
            span: self.merge_spans(start_span, end_span),
        })
    }

    fn parse_guard_statement(&mut self) -> Option<Statement> {
        let start_span = self.cur_token.span;
        self.next_token(); // consume 'guard'

        let mut is_mut = false;
        if self.cur_token.token_type == TokenType::Mut {
            is_mut = true;
            self.next_token(); // consume 'mut'
        }

        if self.cur_token.token_type != TokenType::Ident {
            self.error_at_current("Expected bound variable identifier after 'guard'".to_string());
            return None;
        }
        let name = self.cur_token.literal.clone();
        self.next_token(); // consume identifier

        if self.cur_token.token_type != TokenType::Assign {
            self.error_at_current("Expected ':=' after bound variable name".to_string());
            return None;
        }
        self.next_token(); // consume ':='

        let value = self.parse_expression(1)?;

        self.next_token(); // move to 'else'
        if self.cur_token.token_type != TokenType::Else {
            self.error_at_current("Expected 'else' keyword in guard statement".to_string());
            return None;
        }

        self.next_token(); // move to '{'
        if self.cur_token.token_type != TokenType::LBrace {
            self.error_at_current("Expected '{' for guard else body".to_string());
            return None;
        }

        let else_body = self.parse_block_statement()?;
        let end_span = else_body.span;

        Some(Statement::Guard {
            name,
            is_mut,
            value,
            else_body,
            span: self.merge_spans(start_span, end_span),
        })
    }

    fn parse_while_statement(&mut self) -> Option<Statement> {
        let start_span = self.cur_token.span;
        self.next_token();
        let condition = self.parse_expression(1)?;

        self.next_token();
        if self.cur_token.token_type != TokenType::LBrace {
            return None;
        }

        let body = self.parse_block_statement()?;
        let end_span = body.span;
        Some(Statement::While {
            condition,
            body,
            span: self.merge_spans(start_span, end_span),
        })
    }

    fn parse_if_statement(&mut self) -> Option<Statement> {
        let start_span = self.cur_token.span;
        self.next_token();
        let condition = self.parse_expression(1)?;

        self.next_token();
        if self.cur_token.token_type != TokenType::LBrace {
            return None;
        }
        let consequence = self.parse_block_statement()?;

        let mut alternative = None;
        let mut end_span = consequence.span;
        if self.peek_token.token_type == TokenType::Else {
            self.next_token();
            self.next_token();
            if self.cur_token.token_type == TokenType::If {
                let if_stmt = self.parse_if_statement()?;
                let if_span = if_stmt.span();
                let alt_body = BlockStatement {
                    statements: vec![if_stmt],
                    span: if_span,
                };
                end_span = if_span;
                alternative = Some(alt_body);
            } else if self.cur_token.token_type == TokenType::LBrace {
                let alt_body = self.parse_block_statement()?;
                end_span = alt_body.span;
                alternative = Some(alt_body);
            } else {
                return None;
            }
        }

        Some(Statement::If {
            condition,
            consequence,
            alternative,
            span: self.merge_spans(start_span, end_span),
        })
    }

    fn parse_match_statement(&mut self) -> Option<Statement> {
        let start_span = self.cur_token.span;
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
            let case_start = self.cur_token.span;
            if self.cur_token.token_type != TokenType::Ident {
                return None;
            }
            let variant_name = self.cur_token.literal.clone();
            self.next_token();

            let mut fields = Vec::new();
            if self.cur_token.token_type == TokenType::LBrace {
                self.next_token(); // consume '{'
                while self.cur_token.token_type != TokenType::RBrace
                    && self.cur_token.token_type != TokenType::Eof
                {
                    if self.cur_token.token_type == TokenType::Ident {
                        fields.push(self.cur_token.literal.clone());
                        self.next_token();
                    } else {
                        self.error_at_current(
                            "Expected identifier in match pattern destructuring".to_string(),
                        );
                        return None;
                    }

                    if self.cur_token.token_type == TokenType::Comma {
                        self.next_token();
                    } else if self.cur_token.token_type != TokenType::RBrace {
                        self.error_at_current(
                            "Expected ',' or '}' in match pattern destructuring".to_string(),
                        );
                        return None;
                    }
                }
                if self.cur_token.token_type != TokenType::RBrace {
                    self.error_at_current(
                        "Expected closing brace '}' in match pattern destructuring".to_string(),
                    );
                    return None;
                }
                self.next_token(); // consume '}'
            }

            if self.cur_token.token_type != TokenType::FatArrow {
                self.error_at_current("Expected '=>' after match pattern".to_string());
                return None;
            }
            self.next_token(); // consume '=>'

            if self.cur_token.token_type != TokenType::LBrace {
                return None;
            }
            let body = self.parse_block_statement()?;
            let case_end = body.span;
            // parse_block_statement leaves cur_token at '}'
            self.next_token(); // consume '}'

            cases.push(MatchCase {
                variant_name,
                fields,
                body,
                span: self.merge_spans(case_start, case_end),
            });

            if self.cur_token.token_type == TokenType::Comma {
                self.next_token();
            }
        }

        if self.cur_token.token_type != TokenType::RBrace {
            return None;
        }
        let end_span = self.cur_token.span;
        self.next_token(); // consume '}'

        Some(Statement::Match {
            expression,
            cases,
            span: self.merge_spans(start_span, end_span),
        })
    }

    fn parse_unsafe_block(&mut self) -> Option<Statement> {
        let start_span = self.cur_token.span;
        self.next_token();
        if self.cur_token.token_type != TokenType::LBrace {
            return None;
        }
        let body = self.parse_block_statement()?;
        let end_span = body.span;
        Some(Statement::UnsafeBlock {
            body,
            span: self.merge_spans(start_span, end_span),
        })
    }

    fn parse_return_statement(&mut self) -> Option<Statement> {
        let start_span = self.cur_token.span;
        self.next_token(); // consume 'return'
        if self.cur_token.token_type == TokenType::Semicolon
            || self.cur_token.token_type == TokenType::RBrace
        {
            return Some(Statement::Return(None, start_span));
        }

        let expr = self.parse_expression(1)?;
        let end_span = expr.span();
        Some(Statement::Return(
            Some(expr),
            self.merge_spans(start_span, end_span),
        ))
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
                    let start_span = left.span();
                    let end_span = self.cur_token.span;
                    left = Expression::Selector {
                        left: Box::new(left),
                        right,
                        span: self.merge_spans(start_span, end_span),
                    };
                }
                TokenType::LParen => {
                    self.next_token();
                    let start_span = left.span();
                    let args = self.parse_call_arguments()?;
                    let end_span = self.cur_token.span;
                    left = Expression::Call {
                        function: Box::new(left),
                        arguments: args,
                        span: self.merge_spans(start_span, end_span),
                    };
                }
                TokenType::LBracket => {
                    self.next_token();
                    self.next_token();
                    let start_span = left.span();
                    let index_expr = self.parse_expression(1)?;

                    if self.peek_token.token_type != TokenType::RBracket {
                        return None;
                    }
                    self.next_token();
                    let end_span = self.cur_token.span;

                    left = Expression::IndexAccess {
                        allocator: Box::new(left),
                        index: Box::new(index_expr),
                        span: self.merge_spans(start_span, end_span),
                    };
                }
                TokenType::As => {
                    self.next_token();
                    let start_span = left.span();
                    let mut is_reference = false;

                    if self.peek_token.token_type == TokenType::Ampersand {
                        self.next_token();
                        is_reference = true;
                    }

                    self.next_token();
                    let target_type = self.parse_type_signature()?;
                    let end_span = self.cur_token.span;

                    left = Expression::AsCast {
                        left: Box::new(left),
                        target_type,
                        is_reference,
                        span: self.merge_spans(start_span, end_span),
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
                | TokenType::Gt
                | TokenType::LtEq
                | TokenType::GtEq
                | TokenType::AmpAmp
                | TokenType::PipePipe => {
                    let op_str = self.peek_token.literal.clone();
                    let op_prec = self.peek_token_precedence();

                    self.next_token();
                    self.next_token();

                    let right = self.parse_expression(op_prec)?;
                    let start_span = left.span();
                    let end_span = right.span();
                    left = Expression::Binary {
                        op: op_str,
                        left: Box::new(left),
                        right: Box::new(right),
                        span: self.merge_spans(start_span, end_span),
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
            TokenType::Ident => Some(Expression::Identifier(
                self.cur_token.literal.clone(),
                self.cur_token.span,
            )),
            TokenType::Int => {
                let val: i64 = self.cur_token.literal.parse().ok()?;
                Some(Expression::Integer(val, self.cur_token.span))
            }
            TokenType::String => Some(Expression::String(
                self.cur_token.literal.clone(),
                self.cur_token.span,
            )),
            TokenType::True => Some(Expression::Bool(true, self.cur_token.span)),
            TokenType::False => Some(Expression::Bool(false, self.cur_token.span)),
            TokenType::Move => {
                let start_span = self.cur_token.span;
                self.next_token();
                let expr = self.parse_expression(8)?;
                let end_span = expr.span();
                Some(Expression::Move(
                    Box::new(expr),
                    self.merge_spans(start_span, end_span),
                ))
            }
            TokenType::Take => {
                let start_span = self.cur_token.span;
                self.next_token();
                let expr = self.parse_expression(8)?;
                let end_span = expr.span();
                Some(Expression::Take(
                    Box::new(expr),
                    self.merge_spans(start_span, end_span),
                ))
            }
            TokenType::Ampersand => {
                let start_span = self.cur_token.span;
                self.next_token();
                let expr = self.parse_expression(8)?;
                let end_span = expr.span();
                Some(Expression::AddressOf(
                    Box::new(expr),
                    self.merge_spans(start_span, end_span),
                ))
            }
            TokenType::Asterisk => {
                let start_span = self.cur_token.span;
                self.next_token();
                let expr = self.parse_expression(8)?;
                let end_span = expr.span();
                Some(Expression::Dereference(
                    Box::new(expr),
                    self.merge_spans(start_span, end_span),
                ))
            }
            TokenType::Empty => {
                let start_span = self.cur_token.span;
                self.next_token(); // consume 'empty'
                if self.cur_token.token_type != TokenType::LBracket {
                    return None;
                }
                self.next_token(); // consume '['
                let target_type = self.parse_type_signature()?;
                if self.cur_token.token_type != TokenType::RBracket {
                    return None;
                }
                let end_span = self.cur_token.span;
                Some(Expression::Empty(
                    target_type,
                    self.merge_spans(start_span, end_span),
                ))
            }
            _ => None,
        }
    }

    fn peek_token_precedence(&self) -> i32 {
        match self.peek_token.token_type {
            TokenType::PipePipe => 2,
            TokenType::AmpAmp => 3,
            TokenType::EqEq | TokenType::NotEq => 4,
            TokenType::Lt | TokenType::Gt | TokenType::LtEq | TokenType::GtEq => 5,
            TokenType::Plus | TokenType::Minus => 6,
            TokenType::Asterisk | TokenType::Slash => 7,
            TokenType::As => 8,
            TokenType::Dot | TokenType::LParen | TokenType::LBracket => 9,
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
            Expression::Identifier(name, _) => name.clone(),
            Expression::Integer(val, _) => val.to_string(),
            Expression::String(val, _) => format!("\"{}\"", val),
            Expression::Bool(val, _) => val.to_string(),
            Expression::Move(inner, _) => format!("(move {})", format_expr(inner)),
            Expression::Take(inner, _) => format!("(take {})", format_expr(inner)),
            Expression::AddressOf(inner, _) => format!("(& {})", format_expr(inner)),
            Expression::Dereference(inner, _) => format!("(* {})", format_expr(inner)),
            Expression::IndexAccess {
                allocator, index, ..
            } => {
                format!("{}[{}]", format_expr(allocator), format_expr(index))
            }
            Expression::AsCast {
                left,
                target_type,
                is_reference,
                ..
            } => {
                let ref_str = if *is_reference { "&" } else { "" };
                format!("({} as {}{:?})", format_expr(left), ref_str, target_type)
            }
            Expression::Binary {
                op, left, right, ..
            } => {
                format!("({} {} {})", format_expr(left), op, format_expr(right))
            }
            Expression::Selector { left, right, .. } => {
                format!("{}.{}", format_expr(left), right)
            }
            Expression::Call {
                function,
                arguments,
                ..
            } => {
                let args_strs: Vec<String> = arguments.iter().map(format_expr).collect();
                format!("{}({})", format_expr(function), args_strs.join(", "))
            }
            Expression::Empty(target_type, _) => {
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
        assert_eq!(
            format_expr(&parse_expr_str("a <= b >= c")),
            "((a <= b) >= c)"
        );
    }

    #[test]
    fn test_logical_operator_precedence() {
        assert_eq!(
            format_expr(&parse_expr_str("a < 10 || b > 20 && c == 0")),
            "((a < 10) || ((b > 20) && (c == 0)))"
        );
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
                    Circle { radius } => {
                        return 1;
                    }
                    Rectangle { width, height } => {
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
    fn test_match_pattern_destructuring_parsing() {
        let input = "
            match shape {
                Circle { radius } => {
                    return 1;
                }
                Rectangle { width, height } => {
                    return 2;
                }
                Point => {
                    return 3;
                }
            }
        ";
        let lexer = Lexer::new(input);
        let mut parser = Parser::new(lexer);
        let program = parser.parse_program();
        assert_eq!(parser.errors.len(), 0);
        assert_eq!(program.statements.len(), 1);

        if let Statement::Match { cases, .. } = &program.statements[0] {
            assert_eq!(cases.len(), 3);

            assert_eq!(cases[0].variant_name, "Circle");
            assert_eq!(cases[0].fields, vec!["radius".to_string()]);

            assert_eq!(cases[1].variant_name, "Rectangle");
            assert_eq!(
                cases[1].fields,
                vec!["width".to_string(), "height".to_string()]
            );

            assert_eq!(cases[2].variant_name, "Point");
            assert!(cases[2].fields.is_empty());
        } else {
            panic!("Expected Statement::Match");
        }
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
    fn test_index_primitive_parsing() {
        fn parse_type_str(input: &str) -> Type {
            let lexer = Lexer::new(input);
            let mut parser = Parser::new(lexer);
            parser
                .parse_type_signature()
                .expect("Failed to parse type signature")
        }

        assert_eq!(
            parse_type_str("Index[str, ctx]"),
            Type::Index("str".to_string(), Some("ctx".to_string()))
        );
        assert_eq!(
            parse_type_str("Index[int, ctx]"),
            Type::Index("int".to_string(), Some("ctx".to_string()))
        );
        assert_eq!(
            parse_type_str("Index[byte, ctx]"),
            Type::Index("byte".to_string(), Some("ctx".to_string()))
        );
        assert_eq!(
            parse_type_str("Index[bool, ctx]"),
            Type::Index("bool".to_string(), Some("ctx".to_string()))
        );
        assert_eq!(
            parse_type_str("Index[Arena, ctx]"),
            Type::Index("Arena".to_string(), Some("ctx".to_string()))
        );
    }

    #[test]
    fn test_index_generic_parsing() {
        fn parse_type_str(input: &str) -> Type {
            let lexer = Lexer::new(input);
            let mut parser = Parser::new(lexer);
            parser
                .parse_type_signature()
                .expect("Failed to parse type signature")
        }

        assert_eq!(
            parse_type_str("Index[std.Vector[int, ctx], ctx]"),
            Type::Index("std_Vector_int_ctx".to_string(), Some("ctx".to_string()))
        );
    }

    #[test]
    fn test_parser_span_merging() {
        let expr = parse_expr_str("a + b * c");
        let span = expr.span();
        assert_eq!(span.start.offset, 0);
        assert_eq!(span.end.offset, 9);
    }

    #[test]
    fn test_parser_error_recording() {
        let input = "mut a :=";
        let lexer = Lexer::new(input);
        let mut parser = Parser::new(lexer);

        parser.error_at_current("Unexpected missing expression".to_string());

        assert_eq!(parser.errors.len(), 1);
        let err = &parser.errors[0];
        assert_eq!(err.kind, TypeErrorKind::SyntaxError);
        assert_eq!(err.message, "Unexpected missing expression");
        let span = err.span.unwrap();
        assert_eq!(span.start.line, 1);
        assert_eq!(span.start.column, 1);
    }

    #[test]
    fn test_parser_recovery_on_semicolon() {
        let input = "mut a := ; mut b := 20;";
        let lexer = Lexer::new(input);
        let mut parser = Parser::new(lexer);
        let program = parser.parse_program();

        // Verify we registered the error for mut a := ;
        assert_eq!(parser.errors.len(), 1);
        assert_eq!(parser.errors[0].kind, TypeErrorKind::SyntaxError);

        // Verify we successfully parsed the subsequent mut b := 20; statement
        assert_eq!(program.statements.len(), 1);
        if let Statement::VarDecl { name, value, .. } = &program.statements[0] {
            assert_eq!(name, "b");
            assert!(value.is_some());
        } else {
            panic!("Expected a variable declaration statement for 'b'");
        }
    }

    #[test]
    fn test_detailed_declaration_errors() {
        let input = "type MyStruct struct { field: }";
        let lexer = Lexer::new(input);
        let mut parser = Parser::new(lexer);
        let _program = parser.parse_program();

        assert!(parser.errors.len() >= 1);
        let err = &parser.errors[0];
        assert_eq!(err.kind, TypeErrorKind::SyntaxError);
        assert!(err.message.contains("Expected field type signature"));
    }

    #[test]
    fn test_unclosed_block_recovery() {
        let input = "func main() { mut a := 10; ";
        let lexer = Lexer::new(input);
        let mut parser = Parser::new(lexer);
        let _program = parser.parse_program();

        assert!(parser.errors.len() >= 1);
        let has_unclosed_error = parser
            .errors
            .iter()
            .any(|e| e.message.contains("Expected closing brace '}'"));
        assert!(
            has_unclosed_error,
            "Expected error about missing closing brace '}}'"
        );
    }

    #[test]
    fn test_parse_imports_valid() {
        let input = "import \"std\" as standard; import \"os\"; func main() {}";
        let lexer = Lexer::new(input);
        let mut parser = Parser::new(lexer);
        let program = parser.parse_program();

        assert_eq!(parser.errors.len(), 0);
        assert_eq!(program.statements.len(), 3);

        if let Statement::Import { path, alias, .. } = &program.statements[0] {
            assert_eq!(path, "std");
            assert_eq!(alias.as_deref(), Some("standard"));
        } else {
            panic!("Expected first statement to be import");
        }

        if let Statement::Import { path, alias, .. } = &program.statements[1] {
            assert_eq!(path, "os");
            assert_eq!(alias, &None);
        } else {
            panic!("Expected second statement to be import");
        }
    }

    #[test]
    fn test_parse_imports_misplaced() {
        let input = "func main() {} import \"std\";";
        let lexer = Lexer::new(input);
        let mut parser = Parser::new(lexer);
        let _program = parser.parse_program();

        assert_eq!(parser.errors.len(), 1);
        assert!(
            parser.errors[0]
                .message
                .contains("Imports must be at the beginning of the program")
        );
    }

    #[test]
    fn test_parse_guard_statement() {
        // 1. Immutable guard
        let input1 = "guard a := expr else { return; }";
        let lexer1 = Lexer::new(input1);
        let mut parser1 = Parser::new(lexer1);
        let program1 = parser1.parse_program();
        assert_eq!(parser1.errors.len(), 0);
        assert_eq!(program1.statements.len(), 1);
        if let Statement::Guard { name, is_mut, .. } = &program1.statements[0] {
            assert_eq!(name, "a");
            assert_eq!(*is_mut, false);
        } else {
            panic!("Expected Statement::Guard");
        }

        // 2. Mutable guard
        let input2 = "guard mut a := expr else { os.Exit(1); }";
        let lexer2 = Lexer::new(input2);
        let mut parser2 = Parser::new(lexer2);
        let program2 = parser2.parse_program();
        assert_eq!(parser2.errors.len(), 0);
        assert_eq!(program2.statements.len(), 1);
        if let Statement::Guard { name, is_mut, .. } = &program2.statements[0] {
            assert_eq!(name, "a");
            assert_eq!(*is_mut, true);
        } else {
            panic!("Expected Statement::Guard with mut");
        }

        // 3. Error: missing :=
        let input3 = "guard a expr else { return; }";
        let lexer3 = Lexer::new(input3);
        let mut parser3 = Parser::new(lexer3);
        let _ = parser3.parse_program();
        assert!(parser3.errors.len() >= 1);
        assert!(parser3.errors[0].message.contains("Expected ':='"));

        // 4. Error: missing else
        let input4 = "guard a := expr { return; }";
        let lexer4 = Lexer::new(input4);
        let mut parser4 = Parser::new(lexer4);
        let _ = parser4.parse_program();
        assert!(parser4.errors.len() >= 1);
        assert!(parser4.errors[0].message.contains("Expected 'else'"));

        // 5. Error: missing braces on else block
        let input5 = "guard a := expr else return;";
        let lexer5 = Lexer::new(input5);
        let mut parser5 = Parser::new(lexer5);
        let _ = parser5.parse_program();
        assert!(parser5.errors.len() >= 1);
        assert!(parser5.errors[0].message.contains("Expected '{'"));
    }
}

#[test]
fn test_namespaced_type_signature_parsing() {
    fn parse_type_str(input: &str) -> Type {
        let lexer = Lexer::new(input);
        let mut parser = Parser::new(lexer);
        parser
            .parse_type_signature()
            .expect("Failed to parse type signature")
    }

    let t1 = parse_type_str("std.Vector[int, ctx]");
    if let Type::Generic(name, args) = &t1 {
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

    // Validate boundary of type signature resolution on the TypeChecker
    use crate::typechecker::TypeChecker;
    let mut checker = TypeChecker::new();
    checker.current_prefix = "my_module__".to_string();
    checker
        .imports
        .insert("std".to_string(), "std_".to_string());

    let resolved_t1 = checker.resolve_type(&t1).expect("Failed to resolve t1");
    assert_eq!(
        resolved_t1,
        Type::Struct("std_Vector_int_ctx".to_string(), Some("ctx".to_string()))
    );

    let t2 = parse_type_str("os.Arena");
    assert_eq!(t2, Type::Arena);

    let t3 = parse_type_str("std.HashMap[int, str, ctx]");

    // Validate standard HashMap monomorphization as well
    checker
        .imports
        .insert("std".to_string(), "std_".to_string());
    let resolved_t3 = checker.resolve_type(&t3).expect("Failed to resolve t3");
    assert_eq!(
        resolved_t3,
        Type::Struct(
            "std_HashMap_int_str_ctx".to_string(),
            Some("ctx".to_string())
        )
    );
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

    let t4 = parse_type_str("*int");
    assert!(matches!(t4, Type::RawPointer(inner) if *inner == Type::Int));

    let t5 = parse_type_str("[]byte");
    assert!(matches!(t5, Type::Slice(inner) if *inner == Type::Byte));
}

#[test]
fn test_namespaced_statement_parsing() {
    let input =
        "mut v: std.Vector[int, ctx] := os.VectorNew(ctx); mut a: os.Arena := os.Arena.New();";
    let lexer = Lexer::new(input);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    assert_eq!(program.statements.len(), 2);
}

#[test]
fn test_parser_else_if_desugaring() {
    let input = "
        if a {
            x = 1;
        } else if b {
            x = 2;
        } else {
            x = 3;
        }
    ";
    let lexer = Lexer::new(input);
    let mut parser = Parser::new(lexer);
    let program = parser.parse_program();
    assert_eq!(parser.errors.len(), 0);
    assert_eq!(program.statements.len(), 1);

    if let Statement::If { alternative, .. } = &program.statements[0] {
        assert!(alternative.is_some());
        let alt = alternative.as_ref().unwrap();
        assert_eq!(alt.statements.len(), 1);
        if let Statement::If {
            consequence,
            alternative: nested_alt,
            ..
        } = &alt.statements[0]
        {
            assert_eq!(consequence.statements.len(), 1);
            assert!(nested_alt.is_some());
            let nested_alt_block = nested_alt.as_ref().unwrap();
            assert_eq!(nested_alt_block.statements.len(), 1);
        } else {
            panic!("Expected nested If statement inside desugared else block");
        }
    } else {
        panic!("Expected Statement::If");
    }
}
