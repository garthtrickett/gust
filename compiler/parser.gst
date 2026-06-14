import "token.gst" as token;
import "lexer.gst" as lexer;
import "errors.gst" as errors;
import "ast.gst" as ast;

type ParseResult struct {
    Ok: int,
    Val: token.Token[Any]
}

type Parser[ctx] struct { 
    lexer: *lexer.Lexer[Any],
    cur_token: token.Token[Any],
    peek_token: token.Token[Any],
    pushback_tokens: std.Vector[token.Token[Any], Any],
    errors: std.Vector[errors.CompilerError[Any], Any],
    has_non_import_statement: int
}

func init_parser(p: *Parser[ctx], l: *lexer.Lexer[ctx], ctx: &Arena) { 
    unsafe { 
        (*p).lexer = l as *lexer.Lexer[Any];
        (*p).pushback_tokens = std.VectorNew(ctx);
        (*p).errors = std.VectorNew(ctx);
        (*p).has_non_import_statement = 0;
        
        lexer.next_token((*p).lexer as *lexer.Lexer[ctx], &(*p).cur_token as *token.Token[ctx]);
        lexer.next_token((*p).lexer as *lexer.Lexer[ctx], &(*p).peek_token as *token.Token[ctx]);
    }
}

func next_token(p: *Parser[ctx]) {
    unsafe {
        (*p).cur_token = (*p).peek_token;
        if len((*p).pushback_tokens) > 0 {
            (*p).peek_token = (*p).pushback_tokens.Pop();
        } else {
            lexer.next_token((*p).lexer as *lexer.Lexer[ctx], &(*p).peek_token as *token.Token[ctx]);
        }
    }
}

func cur_token_is(p: *Parser[ctx], tag: int) bool {
    unsafe {
        if (*p).cur_token.token_type.tag == tag {
            return true;
        }
        return false;
    }
}

func peek_token_is(p: *Parser[ctx], tag: int) bool {
    unsafe {
        if (*p).peek_token.token_type.tag == tag {
            return true;
        }
        return false;
    }
}

func expect_peek(p: *Parser[ctx], tag: int, ctx: &Arena) ParseResult {
    unsafe {
        mut res_ptr := p as *ParseResult;
        mut res := *res_ptr;
        if (*p).peek_token.token_type.tag == tag {
            res.Ok = 1;
            res.Val = (*p).peek_token;
            next_token(p);
        } else {
            res.Ok = 0;
            res.Val = (*p).peek_token;
            
            mut err: errors.CompilerError[Any];
            err.kind.tag = 1; // ParserError
            err.message = "Expected token tag";
            err.span = (*p).peek_token.span;
            
            (*p).errors.Push(err);
        }
        return res;
    }
}

func merge_spans(start: token.Span, end: token.Span) token.Span {
    mut s: token.Span;
    s.start = start.start;
    s.end = end.end;
    return s;
}

func is_at_end(p: *Parser[ctx]) int {
    unsafe {
        if cur_token_is(p, 14) { // RBrace = 14
            return 1;
        }
        if cur_token_is(p, 0) { // Eof = 0
            return 1;
        }
        return 0;
    }
}

func parse_type_signature(p: *Parser[ctx], ctx: &Arena) Index[ast.Type[ctx], ctx] {
    mut t_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        if cur_token_is(p, 2) { // Ident = 2
            mut literal := (*p).cur_token.literal;
            if std.str_eq(literal, "int") {
                ctx[t_idx].tag = 0; // Int = 0
            } else if std.str_eq(literal, "bool") {
                ctx[t_idx].tag = 2; // Bool = 2
            } else {
                ctx[t_idx].tag = 8; // Struct = 8
                ctx[t_idx].Struct.struct_name = std.Clone(*ctx, literal);
                ctx[t_idx].Struct.brand = empty[Index[str, ctx]];
            }
            next_token(p);
        } else if cur_token_is(p, 45) { // Bool = 45
            ctx[t_idx].tag = 2; // Bool = 2
            next_token(p);
        }
    }
    return t_idx;
}

func get_expression_span(expr: Index[ast.Expression[ctx], ctx], ctx: &Arena) token.Span { 
    mut s: token.Span;
    unsafe {
        mut tag := ctx[expr].tag;
        if tag == 0 { s = ctx[expr].Identifier.span; }
        else if tag == 1 { s = ctx[expr].Integer.span; }
        else if tag == 2 { s = ctx[expr].String.span; }
        else if tag == 3 { s = ctx[expr].Bool.span; }
        else if tag == 4 { s = ctx[expr].Move.span; }
        else if tag == 5 { s = ctx[expr].Take.span; }
        else if tag == 6 { s = ctx[expr].AddressOf.span; }
        else if tag == 7 { s = ctx[expr].Dereference.span; }
        else if tag == 8 { s = ctx[expr].IndexAccess.span; }
        else if tag == 9 { s = ctx[expr].AsCast.span; }
        else if tag == 10 { s = ctx[expr].Binary.span; }
        else if tag == 11 { s = ctx[expr].Selector.span; }
        else if tag == 12 { s = ctx[expr].Call.span; }
        else if tag == 13 { s = ctx[expr].Empty.span; }
    }
    return s;
}

func peek_token_precedence(p: *Parser[ctx]) int {
    unsafe {
        mut tag := (*p).peek_token.token_type.tag;
        if tag == 51 { // PipePipe = 51
            return 2;
        }
        if tag == 50 { // AmpAmp = 50
            return 3;
        }
        if tag == 23 || tag == 24 { // EqEq = 23, NotEq = 24
            return 4;
        }
        if tag == 25 || tag == 26 || tag == 48 || tag == 49 { // Lt = 25, Gt = 26, LtEq = 48, GtEq = 49
            return 5;
        }
        if tag == 19 || tag == 20 { // Plus = 19, Minus = 20
            return 6;
        }
        if tag == 21 || tag == 22 { // Asterisk = 21, Slash = 22
            return 7;
        }
        if tag == 37 { // As = 37
            return 8;
        }
        if tag == 7 || tag == 11 || tag == 15 { // Dot = 7, LParen = 11, LBracket = 15
            return 9;
        }
        return 1;
    }
}

func parse_prefix_expression(p: *Parser[ctx], ctx: &Arena) Index[ast.Expression[ctx], ctx] {
    mut e_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        mut tag := (*p).cur_token.token_type.tag;
        mut start_span := (*p).cur_token.span;

        if tag == 2 { // Ident = 2
            ctx[e_idx].tag = 0; // Identifier = 0
            ctx[e_idx].Identifier.name = std.Clone(*ctx, (*p).cur_token.literal);
            ctx[e_idx].Identifier.span = (*p).cur_token.span;
            next_token(p);
            return e_idx;
        }
        if tag == 3 { // Int = 3
            ctx[e_idx].tag = 1; // Integer = 1
            ctx[e_idx].Integer.val = std.parse_int((*p).cur_token.literal);
            ctx[e_idx].Integer.span = (*p).cur_token.span;
            next_token(p);
            return e_idx;
        }
        if tag == 4 { // String = 4
            ctx[e_idx].tag = 2; // String = 2
            ctx[e_idx].String.val = std.Clone(*ctx, (*p).cur_token.literal);
            ctx[e_idx].String.span = (*p).cur_token.span;
            next_token(p);
            return e_idx;
        }
        if tag == 46 { // True = 46
            ctx[e_idx].tag = 3; // Bool = 3
            ctx[e_idx].Bool.val = 1;
            ctx[e_idx].Bool.span = (*p).cur_token.span;
            next_token(p);
            return e_idx;
        }
        if tag == 47 { // False = 47
            ctx[e_idx].tag = 3; // Bool = 3
            ctx[e_idx].Bool.val = 0;
            ctx[e_idx].Bool.span = (*p).cur_token.span;
            next_token(p);
            return e_idx;
        }
        if tag == 11 { // LParen = 11
            next_token(p); // consume '('
            mut inner := parse_expression(p, 1, ctx);
            guard rparen_tok := expect_peek(p, 12, ctx) else {
                return empty[Index[ast.Expression[ctx], ctx]];
            }
            return inner;
        }
        if tag == 32 { // Move = 32
            next_token(p); // consume 'move'
            mut inner := parse_expression(p, 8, ctx);
            ctx[e_idx].tag = 4; // Move = 4
            ctx[e_idx].Move.expr = inner;
            ctx[e_idx].Move.span = merge_spans(start_span, get_expression_span(inner, ctx));
            return e_idx;
        }
        if tag == 33 { // Take = 33
            next_token(p); // consume 'take'
            mut inner := parse_expression(p, 8, ctx);
            ctx[e_idx].tag = 5; // Take = 5
            ctx[e_idx].Take.expr = inner;
            ctx[e_idx].Take.span = merge_spans(start_span, get_expression_span(inner, ctx));
            return e_idx;
        }
        if tag == 17 { // Ampersand = 17
            next_token(p); // consume '&'
            mut inner := parse_expression(p, 8, ctx);
            ctx[e_idx].tag = 6; // AddressOf = 6
            ctx[e_idx].AddressOf.expr = inner;
            ctx[e_idx].AddressOf.span = merge_spans(start_span, get_expression_span(inner, ctx));
            return e_idx;
        }
        if tag == 21 { // Asterisk = 21
            next_token(p); // consume '*'
            mut inner := parse_expression(p, 8, ctx);
            ctx[e_idx].tag = 7; // Dereference = 7
            ctx[e_idx].Dereference.expr = inner;
            ctx[e_idx].Dereference.span = merge_spans(start_span, get_expression_span(inner, ctx));
            return e_idx;
        }
        if tag == 44 { // Empty = 44
            next_token(p); // consume 'empty'
            if cur_token_is(p, 15) { // LBracket = 15 ('[')
                next_token(p); // consume '['
            } else {
                return empty[Index[ast.Expression[ctx], ctx]];
            }
            mut target_type := parse_type_signature(p, ctx);
            if cur_token_is(p, 16) { // RBracket = 16 (']')
                next_token(p); // consume ']'
            } else {
                return empty[Index[ast.Expression[ctx], ctx]];
            }
            ctx[e_idx].tag = 13; // Empty = 13
            ctx[e_idx].Empty.target_type = target_type;
            ctx[e_idx].Empty.span = merge_spans(start_span, (*p).cur_token.span);
            return e_idx;
        }
        return empty[Index[ast.Expression[ctx], ctx]];
    }
}

func parse_expression(p: *Parser[ctx], precedence: int, ctx: &Arena) Index[ast.Expression[ctx], ctx] {
    mut left := parse_prefix_expression(p, ctx);
    if left == empty[Index[ast.Expression[ctx], ctx]] {
        return left;
    }
    return left;
}

func parse_statement(p: *Parser[ctx], ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    unsafe {
        if cur_token_is(p, 28) { // Import = 28
            return parse_import_statement(p, ctx);
        }
        (*p).has_non_import_statement = 1;

        if cur_token_is(p, 29) { // Mut = 29
            return parse_var_decl(p, 1, ctx);
        }
        if cur_token_is(p, 34) { // While = 34
            return parse_while_statement(p, ctx);
        }
        if cur_token_is(p, 35) { // If = 35
            return parse_if_statement(p, ctx);
        }
        if cur_token_is(p, 27) { // Guard = 27
            return parse_guard_statement(p, ctx);
        }
        
        if cur_token_is(p, 2) { // Ident = 2
            if peek_token_is(p, 5) { // Assign = 5 (":=")
                return parse_var_decl(p, 0, ctx);
            }
            if peek_token_is(p, 9) { // Colon = 9 (":")
                return parse_var_decl(p, 0, ctx);
            }
        }
        
        mut start_span := (*p).cur_token.span;
        mut left_expr := parse_expression(p, 1, ctx);
        
        if cur_token_is(p, 6) { // Eq = 6 ("=")
            next_token(p); // consume '=' 
            mut right_expr := parse_expression(p, 1, ctx);
            mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[stmt_idx].tag = 5; // Assignment = 5
            ctx[stmt_idx].Assignment.left = left_expr;
            ctx[stmt_idx].Assignment.value = right_expr;
            ctx[stmt_idx].Assignment.span = merge_spans(start_span, (*p).cur_token.span);
            return stmt_idx;
        }
        
        mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[stmt_idx].tag = 13; // Expression = 13
        ctx[stmt_idx].Expression.expr = left_expr;
        ctx[stmt_idx].Expression.span = merge_spans(start_span, (*p).cur_token.span);
        return stmt_idx;
    }
}

func parse_var_decl(p: *Parser[ctx], is_mut: int, ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    mut start_span: token.Span;
    unsafe {
        start_span = (*p).cur_token.span;
        if is_mut == 1 {
            next_token(p); // consume 'mut'
        }
    }
    
    if cur_token_is(p, 2) {
    } else {
        return empty[Index[ast.Statement[ctx], ctx]];
    }
    
    mut name := "";
    unsafe {
        name = std.Clone(*ctx, (*p).cur_token.literal);
        next_token(p); // consume identifier
    }
    
    mut var_type: Index[ast.Type[ctx], ctx] := empty[Index[ast.Type[ctx], ctx]];
    unsafe {
        if cur_token_is(p, 9) { // Colon = 9 (":")
            next_token(p); // consume ':'
            var_type = parse_type_signature(p, ctx);
        }
    }
    
    mut value: Index[ast.Expression[ctx], ctx] := empty[Index[ast.Expression[ctx], ctx]];
    unsafe {
        if cur_token_is(p, 5) { // Assign = 5 (":=")
            next_token(p); // consume ':='
            value = parse_expression(p, 1, ctx);
        }
    }
    
    mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        ctx[stmt_idx].tag = 4; // VarDecl = 4
        ctx[stmt_idx].VarDecl.name = name;
        ctx[stmt_idx].VarDecl.is_mut = is_mut;
        ctx[stmt_idx].VarDecl.value = value;
        ctx[stmt_idx].VarDecl.var_type = var_type;
        ctx[stmt_idx].VarDecl.span = merge_spans(start_span, (*p).cur_token.span);
    }
    return stmt_idx;
}

func parse_block_statement(p: *Parser[ctx], ctx: &Arena) ast.BlockStatement[ctx] {
    mut block: ast.BlockStatement[ctx];
    unsafe {
        block.statements = os.ArenaAlloc(ctx);
        mut dest_ptr := &ctx[block.statements] as *std.Vector[ast.Statement[ctx], ctx];
        *dest_ptr = std.VectorNew(ctx);
        block.span = (*p).cur_token.span;
        
        next_token(p); // consume '{'
        
        while is_at_end(p) == 0 {
            mut stmt := parse_statement(p, ctx);
            (*dest_ptr).Push(ctx[stmt]);
            
            if cur_token_is(p, 10) { // Semicolon = 10
                next_token(p);
            }
        }
        
        block.span = merge_spans(block.span, (*p).cur_token.span);
        if cur_token_is(p, 14) { // RBrace = 14
            next_token(p); // consume '}'
        }
    }
    return block;
}

func parse_while_statement(p: *Parser[ctx], ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    mut start_span: token.Span;
    unsafe {
        start_span = (*p).cur_token.span;
        next_token(p); // consume 'while'
    }
    
    mut condition := parse_expression(p, 1, ctx);
    
    guard lbrace_tok := expect_peek(p, 13, ctx) else { // LBrace = 13
        return empty[Index[ast.Statement[ctx], ctx]];
    }
    
    mut body := parse_block_statement(p, ctx);
    
    mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        ctx[stmt_idx].tag = 6; // While = 6
        ctx[stmt_idx].While.condition = condition;
        ctx[stmt_idx].While.body = body;
        ctx[stmt_idx].While.span = merge_spans(start_span, body.span);
    }
    return stmt_idx;
}

func parse_if_statement(p: *Parser[ctx], ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    mut start_span: token.Span;
    unsafe {
        start_span = (*p).cur_token.span;
        next_token(p); // consume 'if'
    }
    
    mut condition := parse_expression(p, 1, ctx);
    
    guard lbrace_tok := expect_peek(p, 13, ctx) else { // LBrace = 13
        return empty[Index[ast.Statement[ctx], ctx]];
    }
    
    mut consequence := parse_block_statement(p, ctx);
    
    mut alternative: ast.BlockStatement[ctx];
    alternative.statements = empty[Index[std.Vector[ast.Statement[ctx], ctx], ctx]];
    alternative.span = consequence.span;
    
    unsafe {
        if cur_token_is(p, 36) { // Else = 36
            next_token(p); // consume 'else'
            if cur_token_is(p, 13) { // LBrace = 13
                alternative = parse_block_statement(p, ctx);
            }
        }
    }
    
    mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx); 
    unsafe {
        ctx[stmt_idx].tag = 7; // If = 7
        ctx[stmt_idx].If.condition = condition;
        ctx[stmt_idx].If.consequence = consequence;
        ctx[stmt_idx].If.alternative = alternative;
        ctx[stmt_idx].If.span = merge_spans(start_span, (*p).cur_token.span);
    }
    return stmt_idx;
}

func parse_guard_statement(p: *Parser[ctx], ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    mut start_span: token.Span;
    unsafe {
        start_span = (*p).cur_token.span;
        next_token(p); // consume 'guard'
    }
    
    mut is_mut := 0;
    unsafe {
        if cur_token_is(p, 29) { // Mut = 29
            is_mut = 1;
            next_token(p);
        }
    }
    
    if cur_token_is(p, 2) {
    } else {
        return empty[Index[ast.Statement[ctx], ctx]];
    }
    
    mut name := "";
    unsafe {
        name = std.Clone(*ctx, (*p).cur_token.literal);
        next_token(p); // consume identifier
    }
    
    unsafe {
        if cur_token_is(p, 5) { // Assign = 5 (":=")
            next_token(p);
        } else {
            return empty[Index[ast.Statement[ctx], ctx]];
        }
    }
    
    mut value := parse_expression(p, 1, ctx);
    
    unsafe {
        if cur_token_is(p, 36) { // Else = 36
            next_token(p);
        } else {
            return empty[Index[ast.Statement[ctx], ctx]];
        }
    }
    
    guard lbrace_tok := expect_peek(p, 13, ctx) else { // LBrace = 13
        return empty[Index[ast.Statement[ctx], ctx]];
    }
    
    mut else_body := parse_block_statement(p, ctx);
    
    mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        ctx[stmt_idx].tag = 9; // Guard = 9
        ctx[stmt_idx].Guard.name = name;
        ctx[stmt_idx].Guard.is_mut = is_mut;
        ctx[stmt_idx].Guard.value = value;
        ctx[stmt_idx].Guard.else_body = else_body;
        ctx[stmt_idx].Guard.span = merge_spans(start_span, else_body.span);
    }
    return stmt_idx;
}

func parse_program(p: *Parser[ctx], ctx: &Arena) ast.Program[ctx] {
    mut prog: ast.Program[ctx];
    unsafe {
        prog.statements = os.ArenaAlloc(ctx);
        mut dest_ptr := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
        *dest_ptr = std.VectorNew(ctx);
        
        mut start_span := (*p).cur_token.span;
        
        while (*p).cur_token.token_type.tag != 0 { // TokenType::Eof = 0
            mut stmt := parse_statement(p, ctx);
            if stmt != empty[Index[ast.Statement[ctx], ctx]] {
                (*dest_ptr).Push(ctx[stmt]);
            }
            next_token(p);
        }
        prog.span = merge_spans(start_span, (*p).cur_token.span);
    }
    return prog;
}

func parse_import_statement(p: *Parser[ctx], ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    mut start_span := (*p).cur_token.span;
    
    unsafe {
        if (*p).has_non_import_statement == 1 {
            mut err: errors.CompilerError[Any];
            err.kind.tag = 1; // ParserError
            err.message = "Imports must be at the beginning of the program";
            err.span = (*p).cur_token.span;
            (*p).errors.Push(err);
        }
        
        next_token(p); // consume 'import'
        
        if !cur_token_is(p, 4) { // String = 4
            mut err: errors.CompilerError[Any];
            err.kind.tag = 1; // ParserError
            err.message = "Expected string literal specifying the import path";
            err.span = (*p).cur_token.span;
            (*p).errors.Push(err);
            return empty[Index[ast.Statement[ctx], ctx]];
        }
        
        mut path := std.Clone(*ctx, (*p).cur_token.literal);
        next_token(p); // consume string path
        
        mut alias := empty[Index[str, ctx]];
        if cur_token_is(p, 37) { // As = 37
            next_token(p); // consume 'as'
            if !cur_token_is(p, 2) { // Ident = 2
                mut err: errors.CompilerError[Any];
                err.kind.tag = 1; // ParserError
                err.message = "Expected identifier alias after 'as'";
                err.span = (*p).cur_token.span;
                (*p).errors.Push(err);
                return empty[Index[ast.Statement[ctx], ctx]];
            }
            alias = os.ArenaAlloc(ctx);
            ctx[alias] = std.Clone(*ctx, (*p).cur_token.literal);
            next_token(p); // consume alias
        }
        
        mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[stmt_idx].tag = 0; // Import = 0
        ctx[stmt_idx].Import.path = path;
        ctx[stmt_idx].Import.alias = alias;
        ctx[stmt_idx].Import.span = merge_spans(start_span, (*p).cur_token.span);
        return stmt_idx;
    }
}
