import "token.gst" as token;
import "lexer.gst" as lexer;
import "errors.gst" as errors;

type ParseResult struct {
    Ok: int,
    Val: token.Token[Any]
}

type Parser[ctx] struct {
    lexer: *lexer.Lexer[ctx],
    cur_token: token.Token[ctx],
    peek_token: token.Token[ctx],
    pushback_tokens: std.Vector[token.Token[ctx], ctx],
    errors: std.Vector[errors.CompilerError[ctx], ctx]
}

func init_parser(p: *Parser[ctx], l: *lexer.Lexer[ctx], ctx: &Arena) {
    unsafe {
        (*p).lexer = l;
        (*p).pushback_tokens = std.VectorNew(ctx);
        (*p).errors = std.VectorNew(ctx);
        
        lexer.next_token((*p).lexer, &(*p).cur_token);
        lexer.next_token((*p).lexer, &(*p).peek_token);
    }
}

func next_token(p: *Parser[ctx]) {
    unsafe {
        (*p).cur_token = (*p).peek_token;
        if len((*p).pushback_tokens) > 0 {
            (*p).peek_token = (*p).pushback_tokens.Pop();
        } else {
            lexer.next_token((*p).lexer, &(*p).peek_token);
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
            mut val_ptr := &(*p).peek_token as *token.Token[Any];
            res.Val = *val_ptr;
            next_token(p);
        } else {
            res.Ok = 0;
            mut val_ptr := &(*p).peek_token as *token.Token[Any];
            res.Val = *val_ptr;
            
            mut err: errors.CompilerError[ctx];
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
                ctx[t_idx].Struct.struct_name = std.Clone(ctx, literal);
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

func parse_expression(p: *Parser[ctx], precedence: int, ctx: &Arena) Index[ast.Expression[ctx], ctx] {
    mut e_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        if cur_token_is(p, 2) { // Ident = 2
            ctx[e_idx].tag = 0; // Identifier = 0
            ctx[e_idx].Identifier.name = std.Clone(ctx, (*p).cur_token.literal);
            ctx[e_idx].Identifier.span = (*p).cur_token.span;
            next_token(p);
        } else if cur_token_is(p, 3) { // Int = 3
            ctx[e_idx].tag = 1; // Integer = 1
            ctx[e_idx].Integer.val = std.parse_int((*p).cur_token.literal);
            ctx[e_idx].Integer.span = (*p).cur_token.span;
            next_token(p);
        }
    }
    return e_idx;
}

func parse_statement(p: *Parser[ctx], ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    unsafe {
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
        name = std.Clone(ctx, (*p).cur_token.literal);
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
        ctx[block.statements] = std.VectorNew(ctx);
        block.span = (*p).cur_token.span;
        
        next_token(p); // consume '{'
        
        while is_at_end(p) == 0 {
            mut stmt := parse_statement(p, ctx);
            ctx[block.statements].Push(ctx[stmt]);
            
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
        name = std.Clone(ctx, (*p).cur_token.literal);
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
