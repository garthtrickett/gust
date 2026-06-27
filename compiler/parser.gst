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

func parser_get_type_ident(t: ast.Type[ctx], ctx: &Arena) str {
    unsafe {
        mut base := "";
        if t.tag == 0 { // Int
            base = "int";
        } else {
            if t.tag == 1 { // Byte
                base = "byte";
            } else {
                if t.tag == 2 { // Bool
                    base = "bool";
                } else {
                    if t.tag == 3 { // Void
                        base = "void";
                    } else {
                        if t.tag == 4 { // Arena
                            base = "Arena";
                        } else {
                            if t.tag == 5 { // Str
                                base = "str";
                            } else {
                                if t.tag == 6 { // Slice
                                    mut inner_t := ctx[t.Slice.inner];
                                    base = std.Concat("Slice_", parser_get_type_ident(inner_t, ctx));
                                } else {
                                    if t.tag == 7 { // Index
                                        base = std.Concat("Index_", t.Index.struct_name);
                                    } else {
                                        if t.tag == 8 { // Struct
                                            base = t.Struct.struct_name;
                                        } else {
                                            if t.tag == 9 { // RawPointer
                                                mut inner_t := ctx[t.RawPointer.inner];
                                                base = std.Concat(parser_get_type_ident(inner_t, ctx), "_ptr");
                                            } else if t.tag == 11 { // Reference
                                                mut inner_t := ctx[t.Reference.inner];
                                                base = std.Concat(parser_get_type_ident(inner_t, ctx), "_ptr");
                                            } else {
                                                if t.tag == 10 { // Generic
                                                    base = parser_get_monomorphized_name(t.Generic.name, t.Generic.args, ctx);
                                                } else {
                                                    base = "unknown";
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        mut out := "";
        mut i := 0;
        while i < len(base) {
            mut b := std.str_byte_at(base, i);
            if b == 46 { // '.' = 46
                out = std.Concat(out, "_");
            } else {
                mut char_slice := std.str_slice(base, i, i + 1);
                out = std.Concat(out, char_slice);
            }
            i = i + 1;
        }
        return std.Clone(ctx, out);
    }
}

func parser_get_monomorphized_name(template_name: str, args_idx: Index[std.Vector[ast.Type[ctx], ctx], ctx], ctx: &Arena) str {
    unsafe {
        mut args_vec: std.Vector[ast.Type[ctx], ctx] := ctx[args_idx];
        mut arg_names := "";
        mut i := 0;
        while i < len(args_vec) {
            if i > 0 {
                arg_names = std.Concat(arg_names, "_");
            }
            mut arg_name := parser_get_type_ident(args_vec[i], ctx);
            arg_names = std.Concat(arg_names, arg_name);
            i = i + 1;
        }
        mut name := std.Concat(template_name, "_");
        name = std.Concat(name, arg_names);

        mut out := "";
        mut j := 0;
        while j < len(name) {
            mut b := std.str_byte_at(name, j);
            if b == 46 { // '.' = 46
                out = std.Concat(out, "_");
            } else {
                mut char_slice := std.str_slice(name, j, j + 1);
                out = std.Concat(out, char_slice);
            }
            j = j + 1;
        }
        return std.Clone(ctx, out);
    }
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
        mut res: ParseResult;
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

func error_at_current(p: *Parser[ctx], message: str) {
    unsafe {
        mut err: errors.CompilerError[Any];
        err.kind.tag = 1; // ParserError
        err.message = message;
        err.span = (*p).cur_token.span;
        (*p).errors.Push(err);
    }
}

func synchronize(p: *Parser[ctx]) {
    unsafe {
        while (*p).cur_token.token_type.tag != 0 { // TokenType::Eof = 0
            mut tag := (*p).cur_token.token_type.tag;
            if tag == 10 { // Semicolon = 10
                next_token(p); // consume the semicolon
                return;
            }
            if tag == 14 { // RBrace = 14
                // Stop at closing brace so the enclosing block parser can see and handle it
                return;
            }
            if tag == 30 || tag == 39 || tag == 29 || tag == 34 || tag == 35 || tag == 43 || tag == 42 || tag == 31 || tag == 38 || tag == 27 {
                // Func=30, Type=39, Mut=29, While=34, If=35, Return=43, Match=42, Defer=31, Unsafe=38, Guard=27
                return;
            }
            next_token(p);
        }
    }
}

func parse_type_signature(p: *Parser[ctx], ctx: &Arena) Index[ast.Type[ctx], ctx] {
    unsafe {
        if cur_token_is(p, 21) { // Asterisk = 21
            next_token(p);
            mut target := parse_type_signature(p, ctx);
            if target == empty[Index[ast.Type[ctx], ctx]] {
                return empty[Index[ast.Type[ctx], ctx]];
            }
            mut t_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
            mut t_sig_raw_parse: ast.Type[ctx];
            t_sig_raw_parse.tag = 9; // RawPointer = 9
            t_sig_raw_parse.RawPointer.inner = target;
            ctx.Set(t_idx, t_sig_raw_parse);
            return t_idx;
        }

        if cur_token_is(p, 17) { // Ampersand = 17
            next_token(p);
            mut target := parse_type_signature(p, ctx);
            if target == empty[Index[ast.Type[ctx], ctx]] {
                return empty[Index[ast.Type[ctx], ctx]];
            }
            mut t_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
            mut t_sig_ref_parse: ast.Type[ctx];
            t_sig_ref_parse.tag = 11; // Reference = 11
            t_sig_ref_parse.Reference.inner = target;
            t_sig_ref_parse.Reference.brand = empty[Index[str, ctx]];
            ctx.Set(t_idx, t_sig_ref_parse);
            return t_idx;
        }

        if cur_token_is(p, 15) { // LBracket = 15
            next_token(p);
            if cur_token_is(p, 16) == false { // RBracket = 16
                return empty[Index[ast.Type[ctx], ctx]];
            }
            next_token(p);
            mut target := parse_type_signature(p, ctx);
            if target == empty[Index[ast.Type[ctx], ctx]] {
                return empty[Index[ast.Type[ctx], ctx]];
            }
            mut t_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
            mut t_sig_slice_parse: ast.Type[ctx];
            t_sig_slice_parse.tag = 6; // Slice = 6
            t_sig_slice_parse.Slice.inner = target;
            ctx.Set(t_idx, t_sig_slice_parse);
            return t_idx;
        }

        if cur_token_is(p, 2) == false && cur_token_is(p, 45) == false {
            return empty[Index[ast.Type[ctx], ctx]];
        }

        mut base_name := std.Clone(*ctx, (*p).cur_token.literal);
        next_token(p);

        while cur_token_is(p, 7) { // Dot = 7
            next_token(p);
            if cur_token_is(p, 2) == false { // Ident = 2
                return empty[Index[ast.Type[ctx], ctx]];
            }
            base_name = std.Concat(base_name, ".");
            base_name = std.Concat(base_name, (*p).cur_token.literal);
            next_token(p);
        }

        if cur_token_is(p, 15) { // LBracket = 15
            next_token(p);
            mut args_vec: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);

            if cur_token_is(p, 16) == false { // RBracket = 16
                mut first_arg := parse_type_signature(p, ctx);
                if first_arg == empty[Index[ast.Type[ctx], ctx]] {
                    return empty[Index[ast.Type[ctx], ctx]];
                }
                args_vec.Push(ctx[first_arg]);

                while cur_token_is(p, 8) { // Comma = 8
                    next_token(p);
                    mut next_arg := parse_type_signature(p, ctx);
                    if next_arg == empty[Index[ast.Type[ctx], ctx]] {
                        return empty[Index[ast.Type[ctx], ctx]];
                    }
                    args_vec.Push(ctx[next_arg]);
                }
            }

            if cur_token_is(p, 16) == false { // RBracket = 16
                return empty[Index[ast.Type[ctx], ctx]];
            }
            next_token(p);

            if std.str_eq(base_name, "Index") {
                if len(args_vec) == 1 {
                    mut arg0 := args_vec[0];
                    mut brand_name := "";
                    if arg0.tag == 8 { // Struct = 8
                        brand_name = arg0.Struct.struct_name;
                    }
                    mut t_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
                    mut t_sig_index_one_parse: ast.Type[ctx];
                    t_sig_index_one_parse.tag = 7; // Index = 7
                    t_sig_index_one_parse.Index.struct_name = "SessionNode";
                    
                    mut brand_idx_index_one_parse: Index[str, ctx] := os.ArenaAlloc(ctx);
                    t_sig_index_one_parse.Index.brand = brand_idx_index_one_parse;
                    ctx.Set(brand_idx_index_one_parse, std.Clone(*ctx, brand_name));
                    ctx.Set(t_idx, t_sig_index_one_parse);
                    return t_idx;
                } else {
                    if len(args_vec) == 2 {
                        mut arg0 := args_vec[0];
                        mut arg1 := args_vec[1];
                        mut struct_name := "SessionNode";
                        if arg0.tag == 8 { // Struct = 8
                            struct_name = arg0.Struct.struct_name;
                        } else {
                            if arg0.tag == 5 { // Str = 5
                                struct_name = "str";
                            } else {
                                if arg0.tag == 0 { // Int = 0
                                    struct_name = "int";
                                } else {
                                    if arg0.tag == 1 { // Byte = 1
                                        struct_name = "byte";
                                    } else {
                                        if arg0.tag == 2 { // Bool = 2
                                            struct_name = "bool";
                                        } else {
                                            if arg0.tag == 4 { // Arena = 4
                                                struct_name = "Arena";
                                            } else {
                                                if arg0.tag == 10 { // Generic = 10
                                                    struct_name = parser_get_monomorphized_name(arg0.Generic.name, arg0.Generic.args, ctx);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        mut brand_name := "";
                        if arg1.tag == 8 { // Struct = 8
                            brand_name = arg1.Struct.struct_name;
                        }
                        mut t_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
                        mut t_sig_index_two_parse: ast.Type[ctx];
                        t_sig_index_two_parse.tag = 7; // Index = 7
                        t_sig_index_two_parse.Index.struct_name = std.Clone(*ctx, struct_name);
                        
                        mut brand_idx_index_two_parse: Index[str, ctx] := os.ArenaAlloc(ctx);
                        t_sig_index_two_parse.Index.brand = brand_idx_index_two_parse;
                        ctx.Set(brand_idx_index_two_parse, std.Clone(*ctx, brand_name));
                        ctx.Set(t_idx, t_sig_index_two_parse);
                        return t_idx;
                    }
                }
            }

            if len(args_vec) == 1 {
                mut arg0 := args_vec[0];
                mut brand_name := "";
                mut has_brand := 0;
                if arg0.tag == 8 { // Struct = 8
                    brand_name = arg0.Struct.struct_name;
                    has_brand = 1;
                }
                
                mut is_builtin_brand := 0;
                if has_brand == 1 {
                    if std.str_eq(brand_name, "int") || std.str_eq(brand_name, "byte") ||
                       std.str_eq(brand_name, "str") || std.str_eq(brand_name, "Arena") ||
                       std.str_eq(brand_name, "os_Arena") {
                        is_builtin_brand = 1;
                    }
                }

                if has_brand == 1 && is_builtin_brand == 0 {
                    mut t_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
                    mut t_sig_struct_branded_parse: ast.Type[ctx];
                    t_sig_struct_branded_parse.tag = 8; // Struct = 8
                    t_sig_struct_branded_parse.Struct.struct_name = std.Clone(*ctx, base_name);
                    
                    mut brand_idx_struct_branded_parse: Index[str, ctx] := os.ArenaAlloc(ctx);
                    t_sig_struct_branded_parse.Struct.brand = brand_idx_struct_branded_parse;
                    ctx.Set(brand_idx_struct_branded_parse, std.Clone(*ctx, brand_name));
                    ctx.Set(t_idx, t_sig_struct_branded_parse);
                    return t_idx;
                } else {
                    mut t_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
                    mut generic_args_idx_one_parse: Index[std.Vector[ast.Type[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
                    mut t_sig_generic_one_parse: ast.Type[ctx];
                    t_sig_generic_one_parse.tag = 10; // Generic = 10
                    t_sig_generic_one_parse.Generic.name = std.Clone(*ctx, base_name);
                    t_sig_generic_one_parse.Generic.args = generic_args_idx_one_parse;
                    ctx.Set(generic_args_idx_one_parse, args_vec);
                    ctx.Set(t_idx, t_sig_generic_one_parse);
                    return t_idx;
                }
            }

            mut t_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
            mut generic_args_idx_many_parse: Index[std.Vector[ast.Type[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
            mut t_sig_generic_many_parse: ast.Type[ctx];
            t_sig_generic_many_parse.tag = 10; // Generic = 10
            t_sig_generic_many_parse.Generic.name = std.Clone(*ctx, base_name);
            t_sig_generic_many_parse.Generic.args = generic_args_idx_many_parse;
            ctx.Set(generic_args_idx_many_parse, args_vec);
            ctx.Set(t_idx, t_sig_generic_many_parse);
            return t_idx;
        }

        mut t_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
        mut t_sig_named_parse: ast.Type[ctx];
        if std.str_eq(base_name, "int") {
            t_sig_named_parse.tag = 0; // Int = 0
        } else if std.str_eq(base_name, "byte") {
            t_sig_named_parse.tag = 1; // Byte = 1
        } else if std.str_eq(base_name, "bool") {
            t_sig_named_parse.tag = 2; // Bool = 2
        } else if std.str_eq(base_name, "Arena") || std.str_eq(base_name, "os_Arena") || std.str_eq(base_name, "os.Arena") {
            t_sig_named_parse.tag = 4; // Arena = 4
        } else if std.str_eq(base_name, "str") {
            t_sig_named_parse.tag = 5; // Str = 5
        } else {
            t_sig_named_parse.tag = 8; // Struct = 8
            t_sig_named_parse.Struct.struct_name = std.Clone(*ctx, base_name);
            t_sig_named_parse.Struct.brand = empty[Index[str, ctx]];
        }
        ctx.Set(t_idx, t_sig_named_parse);
        return t_idx;
    }
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
            mut e_identifier_parse: ast.Expression[ctx];
            e_identifier_parse.tag = 0; // Identifier = 0
            e_identifier_parse.Identifier.name = std.Clone(*ctx, (*p).cur_token.literal);
            e_identifier_parse.Identifier.span = (*p).cur_token.span;
            ctx.Set(e_idx, e_identifier_parse);
            next_token(p);
            return e_idx;
        }
        if tag == 3 { // Int = 3
            mut e_integer_parse: ast.Expression[ctx];
            e_integer_parse.tag = 1; // Integer = 1
            e_integer_parse.Integer.val = std.parse_int((*p).cur_token.literal);
            e_integer_parse.Integer.span = (*p).cur_token.span;
            ctx.Set(e_idx, e_integer_parse);
            next_token(p);
            return e_idx;
        }
        if tag == 4 { // String = 4
            mut e_string_parse: ast.Expression[ctx];
            e_string_parse.tag = 2; // String = 2
            e_string_parse.String.val = std.Clone(*ctx, (*p).cur_token.literal);
            e_string_parse.String.span = (*p).cur_token.span;
            ctx.Set(e_idx, e_string_parse);
            next_token(p);
            return e_idx;
        }
        if tag == 46 { // True = 46
            mut e_true_parse: ast.Expression[ctx];
            e_true_parse.tag = 3; // Bool = 3
            e_true_parse.Bool.val = 1;
            e_true_parse.Bool.span = (*p).cur_token.span;
            ctx.Set(e_idx, e_true_parse);
            next_token(p);
            return e_idx;
        }
        if tag == 47 { // False = 47
            mut e_false_parse: ast.Expression[ctx];
            e_false_parse.tag = 3; // Bool = 3
            e_false_parse.Bool.val = 0;
            e_false_parse.Bool.span = (*p).cur_token.span;
            ctx.Set(e_idx, e_false_parse);
            next_token(p);
            return e_idx;
        }
        if tag == 11 { // LParen = 11
            next_token(p); // consume '('
            mut inner := parse_expression(p, 1, ctx);
            if cur_token_is(p, 12) == false { // RParen = 12
                return empty[Index[ast.Expression[ctx], ctx]];
            }
            next_token(p); // consume ')'
            return inner;
        }
        if tag == 32 { // Move = 32
            next_token(p); // consume 'move'
            mut inner := parse_expression(p, 8, ctx);
            mut e_move_parse: ast.Expression[ctx];
            e_move_parse.tag = 4; // Move = 4
            e_move_parse.Move.expr = inner;
            e_move_parse.Move.span = merge_spans(start_span, get_expression_span(inner, ctx));
            ctx.Set(e_idx, e_move_parse);
            return e_idx;
        }
        if tag == 33 { // Take = 33
            next_token(p); // consume 'take'
            mut inner := parse_expression(p, 8, ctx);
            mut e_take_parse: ast.Expression[ctx];
            e_take_parse.tag = 5; // Take = 5
            e_take_parse.Take.expr = inner;
            e_take_parse.Take.span = merge_spans(start_span, get_expression_span(inner, ctx));
            ctx.Set(e_idx, e_take_parse);
            return e_idx;
        }
        if tag == 17 { // Ampersand = 17
            next_token(p); // consume '&'
            mut inner := parse_expression(p, 8, ctx);
            mut e_address_parse: ast.Expression[ctx];
            e_address_parse.tag = 6; // AddressOf = 6
            e_address_parse.AddressOf.expr = inner;
            e_address_parse.AddressOf.span = merge_spans(start_span, get_expression_span(inner, ctx));
            ctx.Set(e_idx, e_address_parse);
            return e_idx;
        }
        if tag == 21 { // Asterisk = 21
            next_token(p); // consume '*'
            mut inner := parse_expression(p, 8, ctx);
            mut e_deref_parse: ast.Expression[ctx];
            e_deref_parse.tag = 7; // Dereference = 7
            e_deref_parse.Dereference.expr = inner;
            e_deref_parse.Dereference.span = merge_spans(start_span, get_expression_span(inner, ctx));
            ctx.Set(e_idx, e_deref_parse);
            return e_idx;
        }
        if tag == 44 { // Empty = 44
            next_token(p); // consume 'empty'
            if cur_token_is(p, 15) { // LBracket = 15 ('[')
                next_token(p); // consume '['
            } else {
                error_at_current(p, "Syntax Error: Expected '[' after empty");
                return empty[Index[ast.Expression[ctx], ctx]];
            }
            mut target_type := parse_type_signature(p, ctx);
            if cur_token_is(p, 16) { // RBracket = 16 (']')
                next_token(p); // consume ']'
            } else {
                error_at_current(p, "Syntax Error: Expected ']' after empty type signature");
                return empty[Index[ast.Expression[ctx], ctx]];
            }
            mut e_empty_parse: ast.Expression[ctx];
            e_empty_parse.tag = 13; // Empty = 13
            e_empty_parse.Empty.target_type = target_type;
            e_empty_parse.Empty.span = merge_spans(start_span, (*p).cur_token.span);
            ctx.Set(e_idx, e_empty_parse);
            return e_idx;
        }
        return empty[Index[ast.Expression[ctx], ctx]];
    }
}

func cur_token_precedence(p: *Parser[ctx]) int {
    unsafe {
        mut tag := (*p).cur_token.token_type.tag;
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

// parse_expression executes the full Pratt parsing loop under the consumed convention,
// resolving nested binary expressions, member selectors, indexes, and function calls.
func parse_expression(p: *Parser[ctx], precedence: int, ctx: &Arena) Index[ast.Expression[ctx], ctx] {
    unsafe {
        mut left := parse_prefix_expression(p, ctx);
        if left == empty[Index[ast.Expression[ctx], ctx]] {
            return left;
        }

        while precedence < cur_token_precedence(p) {
            if cur_token_is(p, 10) { // Semicolon = 10
                return left;
            }
            mut cur_tag := (*p).cur_token.token_type.tag;
            
            if cur_tag == 7 { // Dot = 7
                mut start_span := get_expression_span(left, ctx);
                next_token(p); // consume '.'
                if cur_token_is(p, 2) == false { // Ident = 2
                    return empty[Index[ast.Expression[ctx], ctx]];
                }
                mut right := std.Clone(*ctx, (*p).cur_token.literal);
                mut end_span := (*p).cur_token.span;
                next_token(p); // consume member ident
                
                mut next_expr_selector_parse: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                mut e_selector_parse: ast.Expression[ctx];
                e_selector_parse.tag = 11; // Selector = 11
                e_selector_parse.Selector.left = left;
                e_selector_parse.Selector.right = right;
                e_selector_parse.Selector.span = merge_spans(start_span, end_span);
                ctx.Set(next_expr_selector_parse, e_selector_parse);
                left = next_expr_selector_parse;
            } else if cur_tag == 11 { // LParen = 11
                mut start_span := get_expression_span(left, ctx);
                next_token(p); // consume '('
                
                // Parse arguments list
                mut args_vec: std.Vector[ast.Expression[ctx], ctx] := std.VectorNew(ctx);
                if cur_token_is(p, 12) == false { // RParen = 12
                    args_vec.Push(ctx[parse_expression(p, 1, ctx)]);
                    while cur_token_is(p, 8) { // Comma = 8
                        next_token(p); // consume comma
                        args_vec.Push(ctx[parse_expression(p, 1, ctx)]);
                    }
                }
                if cur_token_is(p, 12) == false { // RParen = 12
                    return empty[Index[ast.Expression[ctx], ctx]];
                }
                mut end_span := (*p).cur_token.span;
                next_token(p); // consume ')'
                
                mut next_expr_call_parse: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                mut call_args_idx_parse: Index[std.Vector[ast.Expression[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
                mut e_call_parse: ast.Expression[ctx];
                e_call_parse.tag = 12; // Call = 12
                e_call_parse.Call.function = left;
                e_call_parse.Call.arguments = call_args_idx_parse;
                e_call_parse.Call.span = merge_spans(start_span, end_span);
                ctx.Set(call_args_idx_parse, args_vec);
                ctx.Set(next_expr_call_parse, e_call_parse);
                left = next_expr_call_parse;
            } else if cur_tag == 15 { // LBracket = 15
                mut start_span := get_expression_span(left, ctx);
                next_token(p); // consume '['
                mut index_expr := parse_expression(p, 1, ctx);
                if cur_token_is(p, 16) == false { // RBracket = 16
                    return empty[Index[ast.Expression[ctx], ctx]];
                }
                mut end_span := (*p).cur_token.span;
                next_token(p); // consume ']'
                
                mut next_expr_index_parse: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                mut e_index_parse: ast.Expression[ctx];
                e_index_parse.tag = 8; // IndexAccess = 8
                e_index_parse.IndexAccess.allocator = left;
                e_index_parse.IndexAccess.index = index_expr;
                e_index_parse.IndexAccess.span = merge_spans(start_span, end_span);
                ctx.Set(next_expr_index_parse, e_index_parse);
                left = next_expr_index_parse;
            } else if cur_tag == 37 { // As = 37
                mut start_span := get_expression_span(left, ctx);
                next_token(p); // consume 'as'
                mut is_reference := 0;
                if cur_token_is(p, 17) { // Ampersand = 17
                    next_token(p); // consume '&'
                    is_reference = 1;
                }
                mut target_type := parse_type_signature(p, ctx);
                mut end_span := (*p).cur_token.span;
                
                mut next_expr_cast_parse: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                mut e_cast_parse: ast.Expression[ctx];
                e_cast_parse.tag = 9; // AsCast = 9
                e_cast_parse.AsCast.left = left;
                e_cast_parse.AsCast.target_type = target_type;
                e_cast_parse.AsCast.is_reference = is_reference;
                e_cast_parse.AsCast.span = merge_spans(start_span, end_span);
                ctx.Set(next_expr_cast_parse, e_cast_parse);
                left = next_expr_cast_parse;
            } else if cur_tag == 19 || cur_tag == 20 || cur_tag == 21 || cur_tag == 22 ||
                      cur_tag == 23 || cur_tag == 24 || cur_tag == 25 || cur_tag == 26 ||
                      cur_tag == 48 || cur_tag == 49 || cur_tag == 50 || cur_tag == 51 {
                mut op_str := (*p).cur_token.literal;
                mut op_prec := cur_token_precedence(p);
                
                next_token(p); // consume operator
                
                mut right := parse_expression(p, op_prec, ctx);
                mut start_span := get_expression_span(left, ctx);
                mut end_span := get_expression_span(right, ctx);
                
                mut next_expr_binary_parse: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
                mut e_binary_parse: ast.Expression[ctx];
                e_binary_parse.tag = 10; // Binary = 10
                e_binary_parse.Binary.op = std.Clone(*ctx, op_str);
                e_binary_parse.Binary.left = left;
                e_binary_parse.Binary.right = right;
                e_binary_parse.Binary.span = merge_spans(start_span, end_span);
                ctx.Set(next_expr_binary_parse, e_binary_parse);
                left = next_expr_binary_parse;
            } else {
                return left;
            }
        }
        return left;
    }
}

func parse_struct_decl(p: *Parser[ctx], ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    unsafe {
        mut start_span := (*p).cur_token.span;
        next_token(p); // consume 'type'
        if cur_token_is(p, 2) == false { // Ident = 2
            mut err: errors.CompilerError[Any];
            err.kind.tag = 1; // ParserError
            err.message = "Expected identifier after 'type'";
            err.span = (*p).cur_token.span;
            (*p).errors.Push(err);
            return empty[Index[ast.Statement[ctx], ctx]];
        }
        mut name := std.Clone(*ctx, (*p).cur_token.literal);
        next_token(p);

        mut generics_vec: std.Vector[str, ctx] := std.VectorNew(ctx);
        if cur_token_is(p, 15) { // LBracket = 15
            next_token(p); // consume '['
            while cur_token_is(p, 2) { // Ident = 2
                generics_vec.Push(std.Clone(*ctx, (*p).cur_token.literal));
                next_token(p);
                if cur_token_is(p, 8) { // Comma = 8
                    next_token(p);
                }
            }
            if cur_token_is(p, 16) == false { // RBracket = 16
                mut err: errors.CompilerError[Any];
                err.kind.tag = 1; // ParserError
                err.message = "Expected closing bracket ']' in generic type parameters";
                err.span = (*p).cur_token.span;
                (*p).errors.Push(err);
                return empty[Index[ast.Statement[ctx], ctx]];
            }
            next_token(p); // consume ']'
        }

        if cur_token_is(p, 40) { // Struct = 40
            next_token(p); // consume 'struct'
            if cur_token_is(p, 13) == false { // LBrace = 13
                mut err: errors.CompilerError[Any];
                err.kind.tag = 1; // ParserError
                err.message = "Expected opening brace '{' after 'struct'";
                err.span = (*p).cur_token.span;
                (*p).errors.Push(err);
                return empty[Index[ast.Statement[ctx], ctx]];
            }
            next_token(p); // consume '{'

            mut fields_vec: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
            while cur_token_is(p, 14) == false && cur_token_is(p, 0) == false { // RBrace = 14, Eof = 0
                if cur_token_is(p, 2) { // Ident = 2
                    mut f_start := (*p).cur_token.span;
                    mut f_name := std.Clone(*ctx, (*p).cur_token.literal);
                    next_token(p);

                    if cur_token_is(p, 9) == false { // Colon = 9
                        mut err: errors.CompilerError[Any];
                        err.kind.tag = 1; // ParserError
                        err.message = "Expected ':' after struct field identifier";
                        err.span = (*p).cur_token.span;
                        (*p).errors.Push(err);
                        return empty[Index[ast.Statement[ctx], ctx]];
                    }
                    next_token(p); // consume ':'

                    mut f_type := parse_type_signature(p, ctx);
                    if f_type == empty[Index[ast.Type[ctx], ctx]] {
                        mut err: errors.CompilerError[Any];
                        err.kind.tag = 1; // ParserError
                        err.message = "Expected field type signature";
                        err.span = (*p).cur_token.span;
                        (*p).errors.Push(err);
                        return empty[Index[ast.Statement[ctx], ctx]];
                    }
                    mut f_end := (*p).cur_token.span;

                    mut field: ast.FieldDef[ctx];
                    field.name = f_name;
                    field.field_type = ctx[f_type];
                    field.span = merge_spans(f_start, f_end);
                    fields_vec.Push(field);

                    if cur_token_is(p, 8) || cur_token_is(p, 10) { // Comma = 8, Semicolon = 10
                        next_token(p);
                    }
                } else {
                    mut err: errors.CompilerError[Any];
                    err.kind.tag = 1; // ParserError
                    err.message = "Expected struct field identifier or '}'";
                    err.span = (*p).cur_token.span;
                    (*p).errors.Push(err);
                    return empty[Index[ast.Statement[ctx], ctx]];
                }
            }

            if cur_token_is(p, 14) == false { // RBrace = 14
                mut err: errors.CompilerError[Any];
                err.kind.tag = 1; // ParserError
                err.message = "Expected closing brace '}' after struct fields";
                err.span = (*p).cur_token.span;
                (*p).errors.Push(err);
                return empty[Index[ast.Statement[ctx], ctx]];
            }
            mut end_span := (*p).cur_token.span;
            next_token(p); // consume '}'

            mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
            mut struct_generics_idx_parse: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
            mut struct_fields_idx_parse: Index[std.Vector[ast.FieldDef[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
            mut stmt_struct_parse: ast.Statement[ctx];
            stmt_struct_parse.tag = 1; // StructDecl = 1

            stmt_struct_parse.StructDecl.name = name;

            stmt_struct_parse.StructDecl.generics = struct_generics_idx_parse;
            ctx.Set(struct_generics_idx_parse, generics_vec);

            stmt_struct_parse.StructDecl.fields = struct_fields_idx_parse;
            ctx.Set(struct_fields_idx_parse, fields_vec);

            stmt_struct_parse.StructDecl.span = merge_spans(start_span, end_span);
            ctx.Set(stmt_idx, stmt_struct_parse);
            return stmt_idx;
        } else if cur_token_is(p, 41) { // Enum = 41
            next_token(p); // consume 'enum'

            if cur_token_is(p, 13) == false { // LBrace = 13
                mut err: errors.CompilerError[Any];
                err.kind.tag = 1; // ParserError
                err.message = "Expected opening brace '{' after 'enum'";
                err.span = (*p).cur_token.span;
                (*p).errors.Push(err);
                return empty[Index[ast.Statement[ctx], ctx]];
            }
            next_token(p); // consume '{'

            mut variants_vec: std.Vector[ast.VariantDef[ctx], ctx] := std.VectorNew(ctx);
            while cur_token_is(p, 14) == false && cur_token_is(p, 0) == false { // RBrace = 14, Eof = 0
                if cur_token_is(p, 2) { // Ident = 2
                    mut variant_start := (*p).cur_token.span;
                    mut variant_name := std.Clone(*ctx, (*p).cur_token.literal);
                    next_token(p);

                    mut fields_vec: std.Vector[ast.FieldDef[ctx], ctx] := std.VectorNew(ctx);
                    if cur_token_is(p, 13) { // LBrace = 13
                        next_token(p); // consume '{'
                        while cur_token_is(p, 14) == false && cur_token_is(p, 0) == false { // RBrace = 14, Eof = 0
                            if cur_token_is(p, 2) { // Ident = 2
                                mut f_start := (*p).cur_token.span;
                                mut f_name := std.Clone(*ctx, (*p).cur_token.literal);
                                next_token(p);

                                if cur_token_is(p, 9) == false { // Colon = 9
                                    mut err: errors.CompilerError[Any];
                                    err.kind.tag = 1; // ParserError
                                    err.message = "Expected ':' after enum variant field identifier";
                                    err.span = (*p).cur_token.span;
                                    (*p).errors.Push(err);
                                    return empty[Index[ast.Statement[ctx], ctx]];
                                }
                                next_token(p); // consume ':'

                                mut f_type := parse_type_signature(p, ctx);
                                if f_type == empty[Index[ast.Type[ctx], ctx]] {
                                    mut err: errors.CompilerError[Any];
                                    err.kind.tag = 1; // ParserError
                                    err.message = "Expected field type signature";
                                    err.span = (*p).cur_token.span;
                                    (*p).errors.Push(err);
                                    return empty[Index[ast.Statement[ctx], ctx]];
                                }
                                mut f_end := (*p).cur_token.span;

                                mut field: ast.FieldDef[ctx];
                                field.name = f_name;
                                field.field_type = ctx[f_type];
                                field.span = merge_spans(f_start, f_end);
                                fields_vec.Push(field);

                                if cur_token_is(p, 8) || cur_token_is(p, 10) { // Comma = 8, Semicolon = 10
                                    next_token(p);
                                }
                            } else {
                                mut err: errors.CompilerError[Any];
                                err.kind.tag = 1; // ParserError
                                err.message = "Expected enum variant field identifier or '}'";
                                err.span = (*p).cur_token.span;
                                (*p).errors.Push(err);
                                return empty[Index[ast.Statement[ctx], ctx]];
                            }
                        }
                        if cur_token_is(p, 14) == false { // RBrace = 14
                            mut err: errors.CompilerError[Any];
                            err.kind.tag = 1; // ParserError
                            err.message = "Expected closing brace '}' after enum variant fields";
                            err.span = (*p).cur_token.span;
                            (*p).errors.Push(err);
                            return empty[Index[ast.Statement[ctx], ctx]];
                        }
                        next_token(p); // consume '}'
                    }
                    mut variant_end := (*p).cur_token.span;

                    mut variant: ast.VariantDef[ctx];
                    variant.name = variant_name;
                    variant.fields = os.ArenaAlloc(ctx);
                    ctx.Set(variant.fields, fields_vec);
                    variant.span = merge_spans(variant_start, variant_end);
                    variants_vec.Push(variant);

                    if cur_token_is(p, 8) || cur_token_is(p, 10) { // Comma = 8, Semicolon = 10
                        next_token(p);
                    }
                } else {
                    mut err: errors.CompilerError[Any];
                    err.kind.tag = 1; // ParserError
                    err.message = "Expected enum variant identifier or '}'";
                    err.span = (*p).cur_token.span;
                    (*p).errors.Push(err);
                    return empty[Index[ast.Statement[ctx], ctx]];
                }
            }

            if cur_token_is(p, 14) == false { // RBrace = 14
                mut err: errors.CompilerError[Any];
                err.kind.tag = 1; // ParserError
                err.message = "Expected closing brace '}' after enum variants";
                err.span = (*p).cur_token.span;
                (*p).errors.Push(err);
                return empty[Index[ast.Statement[ctx], ctx]];
            }
            mut end_span := (*p).cur_token.span;
            next_token(p); // consume '}'

            mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
            mut enum_generics_idx_parse: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
            mut enum_variants_idx_parse: Index[std.Vector[ast.VariantDef[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
            mut stmt_enum_parse: ast.Statement[ctx];
            stmt_enum_parse.tag = 2; // EnumDecl = 2

            stmt_enum_parse.EnumDecl.name = name;

            stmt_enum_parse.EnumDecl.generics = enum_generics_idx_parse;
            ctx.Set(enum_generics_idx_parse, generics_vec);

            stmt_enum_parse.EnumDecl.variants = enum_variants_idx_parse;
            ctx.Set(enum_variants_idx_parse, variants_vec);

            stmt_enum_parse.EnumDecl.span = merge_spans(start_span, end_span);
            ctx.Set(stmt_idx, stmt_enum_parse);
            return stmt_idx;
        } else {
            mut err: errors.CompilerError[Any];
            err.kind.tag = 1; // ParserError
            err.message = "Expected 'struct' or 'enum' declaration";
            err.span = (*p).cur_token.span;
            (*p).errors.Push(err);
            return empty[Index[ast.Statement[ctx], ctx]];
        }
    }
}

func parse_function_decl(p: *Parser[ctx], ctx: &Arena) Index[ast.Statement[ctx], ctx] { 
    unsafe {
        mut start_span := (*p).cur_token.span;
        mut is_unsafe_decl := 0;
        if cur_token_is(p, 38) { // Unsafe = 38
            is_unsafe_decl = 1;
            next_token(p); // consume 'unsafe'
        }
        next_token(p); // consume 'func'
        if cur_token_is(p, 2) == false { // Ident = 2
            mut err: errors.CompilerError[Any];
            err.kind.tag = 1; // ParserError
            err.message = "Expected identifier after 'func'";
            err.span = (*p).cur_token.span;
            (*p).errors.Push(err);
            return empty[Index[ast.Statement[ctx], ctx]];
        }
        mut name := std.Clone(*ctx, (*p).cur_token.literal);
        next_token(p);

        if cur_token_is(p, 11) == false { // LParen = 11
            mut err: errors.CompilerError[Any];
            err.kind.tag = 1; // ParserError
            err.message = "Expected '(' after function name";
            err.span = (*p).cur_token.span;
            (*p).errors.Push(err);
            return empty[Index[ast.Statement[ctx], ctx]];
        }
        next_token(p); // consume '('\n

        mut params_vec: std.Vector[ast.Parameter[ctx], ctx] := std.VectorNew(ctx);
        while cur_token_is(p, 12) == false && cur_token_is(p, 0) == false { // RParen = 12, Eof = 0
            if cur_token_is(p, 2) == false { // Ident = 2
                mut err: errors.CompilerError[Any];
                err.kind.tag = 1; // ParserError
                err.message = "Expected parameter name identifier";
                err.span = (*p).cur_token.span;
                (*p).errors.Push(err);
                return empty[Index[ast.Statement[ctx], ctx]];
            }
            mut param_start := (*p).cur_token.span;
            mut param_name := std.Clone(*ctx, (*p).cur_token.literal);
            next_token(p);

            if cur_token_is(p, 9) == false { // Colon = 9
                mut err: errors.CompilerError[Any];
                err.kind.tag = 1; // ParserError
                err.message = "Expected ':' after parameter name";
                err.span = (*p).cur_token.span;
                (*p).errors.Push(err);
                return empty[Index[ast.Statement[ctx], ctx]];
            }
            next_token(p); // consume ':'

            mut p_type := parse_type_signature(p, ctx);
            if p_type == empty[Index[ast.Type[ctx], ctx]] {
                mut err: errors.CompilerError[Any];
                err.kind.tag = 1; // ParserError
                err.message = "Expected parameter type signature";
                err.span = (*p).cur_token.span;
                (*p).errors.Push(err);
                return empty[Index[ast.Statement[ctx], ctx]];
            }
            mut param_end := (*p).cur_token.span;

            mut param: ast.Parameter[ctx];
            param.name = param_name;
            param.param_type = ctx[p_type];
            param.span = merge_spans(param_start, param_end);
            params_vec.Push(param);

            if cur_token_is(p, 8) { // Comma = 8
                next_token(p); // consume ','
            }
        }

        if cur_token_is(p, 12) == false { // RParen = 12
            mut err: errors.CompilerError[Any];
            err.kind.tag = 1; // ParserError
            err.message = "Expected closing parenthesis ')'";
            err.span = (*p).cur_token.span;
            (*p).errors.Push(err);
            return empty[Index[ast.Statement[ctx], ctx]];
        }
        next_token(p); // consume ')'

        mut r_type: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
        mut default_void_type_parse: ast.Type[ctx];
        default_void_type_parse.tag = 3; // Default Type::Void = 3
        ctx.Set(r_type, default_void_type_parse);
        
        // Parse optional return type
        if cur_token_is(p, 2) || cur_token_is(p, 45) || cur_token_is(p, 15) || cur_token_is(p, 21) || cur_token_is(p, 17) {
            mut parsed_r_type := parse_type_signature(p, ctx);
            if parsed_r_type == empty[Index[ast.Type[ctx], ctx]] {
                mut err: errors.CompilerError[Any];
                err.kind.tag = 1; // ParserError
                err.message = "Expected return type signature";
                err.span = (*p).cur_token.span;
                (*p).errors.Push(err);
                return empty[Index[ast.Statement[ctx], ctx]];
            }
            r_type = parsed_r_type;
        }

        if cur_token_is(p, 13) == false { // LBrace = 13
            mut err: errors.CompilerError[Any];
            err.kind.tag = 1; // ParserError
            err.message = "Expected opening brace '{' for function body";
            err.span = (*p).cur_token.span;
            (*p).errors.Push(err);
            return empty[Index[ast.Statement[ctx], ctx]];
        }

        mut body := parse_block_statement(p, ctx);
        mut end_span := ctx[body].span;

        mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        mut function_params_idx_parse: Index[std.Vector[ast.Parameter[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        mut stmt_function_parse: ast.Statement[ctx];
        stmt_function_parse.tag = 3; // FunctionDecl = 3

        stmt_function_parse.FunctionDecl.name = name;
        stmt_function_parse.FunctionDecl.is_unsafe = is_unsafe_decl;

        stmt_function_parse.FunctionDecl.params = function_params_idx_parse;
        ctx.Set(function_params_idx_parse, params_vec);

        stmt_function_parse.FunctionDecl.return_type = r_type;
        stmt_function_parse.FunctionDecl.body = body;
        stmt_function_parse.FunctionDecl.span = merge_spans(start_span, end_span);

        ctx.Set(stmt_idx, stmt_function_parse);
        return stmt_idx;
    }
}

func parse_defer_statement(p: *Parser[ctx], ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    unsafe {
        mut start_span := (*p).cur_token.span;
        next_token(p); // consume 'defer'
        mut expr := parse_expression(p, 1, ctx);
        if expr == empty[Index[ast.Expression[ctx], ctx]] {
            return empty[Index[ast.Statement[ctx], ctx]];
        }
        mut end_span := get_expression_span(expr, ctx);

        mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        mut stmt_defer_parse: ast.Statement[ctx];
        stmt_defer_parse.tag = 11; // Defer = 11
        stmt_defer_parse.Defer.expr = expr;
        stmt_defer_parse.Defer.span = merge_spans(start_span, end_span);
        ctx.Set(stmt_idx, stmt_defer_parse);
        return stmt_idx;
    }
}

func parse_return_statement(p: *Parser[ctx], ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    unsafe {
        mut start_span := (*p).cur_token.span;
        next_token(p); // consume 'return'
        if cur_token_is(p, 10) || cur_token_is(p, 14) { // Semicolon = 10, RBrace = 14
            mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
            mut stmt_return_empty_parse: ast.Statement[ctx];
            stmt_return_empty_parse.tag = 12; // Return = 12
            stmt_return_empty_parse.Return.expr = empty[Index[ast.Expression[ctx], ctx]];
            stmt_return_empty_parse.Return.span = start_span;
            ctx.Set(stmt_idx, stmt_return_empty_parse);
            return stmt_idx;
        }

        mut expr := parse_expression(p, 1, ctx);
        if expr == empty[Index[ast.Expression[ctx], ctx]] {
            return empty[Index[ast.Statement[ctx], ctx]];
        }
        mut end_span := get_expression_span(expr, ctx);

        mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        mut stmt_return_value_parse: ast.Statement[ctx];
        stmt_return_value_parse.tag = 12; // Return = 12
        stmt_return_value_parse.Return.expr = expr;
        stmt_return_value_parse.Return.span = merge_spans(start_span, end_span);
        ctx.Set(stmt_idx, stmt_return_value_parse);
        return stmt_idx;
    }
}

func parse_unsafe_block(p: *Parser[ctx], ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    unsafe {
        mut start_span := (*p).cur_token.span;
        next_token(p); // consume 'unsafe'
        if cur_token_is(p, 13) == false { // LBrace = 13
            return empty[Index[ast.Statement[ctx], ctx]];
        }
        mut body := parse_block_statement(p, ctx);
        mut end_span := ctx[body].span;

        mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        mut stmt_unsafe_parse: ast.Statement[ctx];
        stmt_unsafe_parse.tag = 10; // UnsafeBlock = 10
        stmt_unsafe_parse.UnsafeBlock.body = body;
        stmt_unsafe_parse.UnsafeBlock.span = merge_spans(start_span, end_span);
        ctx.Set(stmt_idx, stmt_unsafe_parse);
        return stmt_idx;
    }
}

func parse_match_statement(p: *Parser[ctx], ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    unsafe {
        mut start_span := (*p).cur_token.span;
        next_token(p); // consume 'match'
        mut expression := parse_expression(p, 1, ctx);
        if expression == empty[Index[ast.Expression[ctx], ctx]] {
            return empty[Index[ast.Statement[ctx], ctx]];
        }

        if cur_token_is(p, 13) == false { // LBrace = 13
            mut err: errors.CompilerError[Any];
            err.kind.tag = 1; // ParserError
            err.message = "Expected '{' after match expression";
            err.span = (*p).cur_token.span;
            (*p).errors.Push(err);
            return empty[Index[ast.Statement[ctx], ctx]];
        }
        next_token(p); // consume '{'

        mut cases_vec: std.Vector[ast.MatchCase[ctx], ctx] := std.VectorNew(ctx);
        while cur_token_is(p, 14) == false && cur_token_is(p, 0) == false { // RBrace = 14, Eof = 0
            mut case_start := (*p).cur_token.span;
            if cur_token_is(p, 2) == false { // Ident = 2
                return empty[Index[ast.Statement[ctx], ctx]];
            }
            mut variant_name := std.Clone(*ctx, (*p).cur_token.literal);
            next_token(p);

            mut fields_vec: std.Vector[str, ctx] := std.VectorNew(ctx);
            if cur_token_is(p, 13) { // LBrace = 13
                next_token(p); // consume '{'
                while cur_token_is(p, 14) == false && cur_token_is(p, 0) == false { // RBrace = 14, Eof = 0
                    if cur_token_is(p, 2) { // Ident = 2
                        fields_vec.Push(std.Clone(*ctx, (*p).cur_token.literal));
                        next_token(p);
                    } else {
                        mut err: errors.CompilerError[Any];
                        err.kind.tag = 1; // ParserError
                        err.message = "Expected identifier in match pattern destructuring";
                        err.span = (*p).cur_token.span;
                        (*p).errors.Push(err);
                        return empty[Index[ast.Statement[ctx], ctx]];
                    }

                    if cur_token_is(p, 8) { // Comma = 8
                        next_token(p);
                    } else if cur_token_is(p, 14) == false { // RBrace = 14
                        mut err: errors.CompilerError[Any];
                        err.kind.tag = 1; // ParserError
                        err.message = "Expected ',' or '}' in match pattern destructuring";
                        err.span = (*p).cur_token.span;
                        (*p).errors.Push(err);
                        return empty[Index[ast.Statement[ctx], ctx]];
                    }
                }
                if cur_token_is(p, 14) == false { // RBrace = 14
                    mut err: errors.CompilerError[Any];
                    err.kind.tag = 1; // ParserError
                    err.message = "Expected closing brace '}' in match pattern destructuring";
                    err.span = (*p).cur_token.span;
                    (*p).errors.Push(err);
                    return empty[Index[ast.Statement[ctx], ctx]];
                }
                next_token(p); // consume '}'
            }

            if cur_token_is(p, 18) == false { // FatArrow = 18
                mut err: errors.CompilerError[Any];
                err.kind.tag = 1; // ParserError
                err.message = "Expected '=>' after match pattern";
                err.span = (*p).cur_token.span;
                (*p).errors.Push(err);
                return empty[Index[ast.Statement[ctx], ctx]];
            }
            next_token(p); // consume '=>'

            if cur_token_is(p, 13) == false { // LBrace = 13
                return empty[Index[ast.Statement[ctx], ctx]];
            }
            mut body := parse_block_statement(p, ctx);
            mut case_end := ctx[body].span;

            mut mcase: ast.MatchCase[ctx];
            mcase.variant_name = variant_name;
            mcase.fields = os.ArenaAlloc(ctx);
            ctx.Set(mcase.fields, fields_vec);
            mcase.body = body;
            mcase.span = merge_spans(case_start, case_end);

            cases_vec.Push(mcase);

            if cur_token_is(p, 8) { // Comma = 8
                next_token(p);
            }
        }

        if cur_token_is(p, 14) == false { // RBrace = 14
            return empty[Index[ast.Statement[ctx], ctx]];
        }
        mut end_span := (*p).cur_token.span;
        next_token(p); // consume '}'

        mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        mut match_cases_idx_parse: Index[std.Vector[ast.MatchCase[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        mut stmt_match_parse: ast.Statement[ctx];
        stmt_match_parse.tag = 8; // Match = 8
        stmt_match_parse.Match.expression = expression;
        stmt_match_parse.Match.cases = match_cases_idx_parse;
        stmt_match_parse.Match.span = merge_spans(start_span, end_span);
        ctx.Set(match_cases_idx_parse, cases_vec);
        ctx.Set(stmt_idx, stmt_match_parse);

        return stmt_idx;
    }
}

func parse_statement(p: *Parser[ctx], ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    unsafe { 
        if cur_token_is(p, 28) { // Import = 28
            return parse_import_statement(p, ctx);
        }
        (*p).has_non_import_statement = 1;

        if cur_token_is(p, 39) { // Type = 39
            return parse_struct_decl(p, ctx);
        }

        if cur_token_is(p, 30) { // Func = 30
            return parse_function_decl(p, ctx);
        }

        if cur_token_is(p, 31) { // Defer = 31
            return parse_defer_statement(p, ctx);
        }

        if cur_token_is(p, 38) { // Unsafe = 38
            if peek_token_is(p, 30) { // Func = 30
                return parse_function_decl(p, ctx);
            }
            return parse_unsafe_block(p, ctx);
        }

        if cur_token_is(p, 43) { // Return = 43
            return parse_return_statement(p, ctx);
        }

        if cur_token_is(p, 42) { // Match = 42
            return parse_match_statement(p, ctx);
        }

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
        if left_expr == empty[Index[ast.Expression[ctx], ctx]] {
            return empty[Index[ast.Statement[ctx], ctx]];
        }
        
        if cur_token_is(p, 6) { // Eq = 6 ("=")
            next_token(p); // consume '=' 
            mut right_expr := parse_expression(p, 1, ctx);
            if right_expr == empty[Index[ast.Expression[ctx], ctx]] {
                return empty[Index[ast.Statement[ctx], ctx]];
            }
            mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
            mut stmt_assignment_parse: ast.Statement[ctx];
            stmt_assignment_parse.tag = 5; // Assignment = 5
            stmt_assignment_parse.Assignment.left = left_expr;
            stmt_assignment_parse.Assignment.value = right_expr;
            stmt_assignment_parse.Assignment.span = merge_spans(start_span, (*p).cur_token.span);
            ctx.Set(stmt_idx, stmt_assignment_parse);
            return stmt_idx;
        }
        
        mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        mut stmt_expression_parse: ast.Statement[ctx];
        stmt_expression_parse.tag = 13; // Expression = 13
        stmt_expression_parse.Expression.expr = left_expr;
        stmt_expression_parse.Expression.span = merge_spans(start_span, (*p).cur_token.span);
        ctx.Set(stmt_idx, stmt_expression_parse);
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
        mut stmt_var_decl_parse: ast.Statement[ctx];
        stmt_var_decl_parse.tag = 4; // VarDecl = 4
        stmt_var_decl_parse.VarDecl.name = name;
        stmt_var_decl_parse.VarDecl.is_mut = is_mut;
        stmt_var_decl_parse.VarDecl.value = value;
        stmt_var_decl_parse.VarDecl.var_type = var_type;
        stmt_var_decl_parse.VarDecl.span = merge_spans(start_span, (*p).cur_token.span);
        ctx.Set(stmt_idx, stmt_var_decl_parse);
    }
    return stmt_idx;
}

func parse_block_statement(p: *Parser[ctx], ctx: &Arena) Index[ast.BlockStatement[ctx], ctx] {
    mut block_idx: Index[ast.BlockStatement[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        mut statements_vec: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
        mut dest_ptr := &statements_vec;
        mut block_start_span_parse := (*p).cur_token.span;

        next_token(p);

               while is_at_end(p) == 0 {
                    mut before_errors := len((*p).errors);
                    mut stmt := parse_statement(p, ctx);
                    if stmt != empty[Index[ast.Statement[ctx], ctx]] {
                        (*dest_ptr).Push(ctx[stmt]);
                        if cur_token_is(p, 10) { // Semicolon = 10
                            next_token(p);
                        }
                    } else {
                        if len((*p).errors) == before_errors {
                            error_at_current(p, "Syntax Error: Expected valid statement inside block");
                        }
                        mut before_sync := (*p).cur_token.token_type.tag;
                synchronize(p);
                if (*p).cur_token.token_type.tag == before_sync {
                    next_token(p);
                }
            }
        }
        
        mut block_statements_idx_parse: Index[std.Vector[ast.Statement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
        mut block_parse: ast.BlockStatement[ctx];
        block_parse.statements = block_statements_idx_parse;
        block_parse.span = merge_spans(block_start_span_parse, (*p).cur_token.span);
        ctx.Set(block_statements_idx_parse, statements_vec);
        ctx.Set(block_idx, block_parse);
        if cur_token_is(p, 14) { // RBrace = 14
            next_token(p); // consume '}'
        }
    }
    return block_idx;
}

func parse_while_statement(p: *Parser[ctx], ctx: &Arena) Index[ast.Statement[ctx], ctx] { 
    mut start_span: token.Span;
    unsafe {
        start_span = (*p).cur_token.span;
        next_token(p); // consume 'while'
    }
    
    mut condition := parse_expression(p, 1, ctx);
    
    if cur_token_is(p, 13) == false { // LBrace = 13
        unsafe {
            mut err: errors.CompilerError[Any];
            err.kind.tag = 1; // ParserError
            err.message = "Expected '{' after while condition";
            err.span = (*p).cur_token.span;
            (*p).errors.Push(err);
        }
        return empty[Index[ast.Statement[ctx], ctx]];
    }
    
    mut body := parse_block_statement(p, ctx);
    
    mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx); 
    unsafe {
        mut stmt_while_parse: ast.Statement[ctx];
        stmt_while_parse.tag = 6; // While = 6
        stmt_while_parse.While.condition = condition;
        stmt_while_parse.While.body = body;
        stmt_while_parse.While.span = merge_spans(start_span, ctx[body].span);
        ctx.Set(stmt_idx, stmt_while_parse);
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
    
    if cur_token_is(p, 13) == false { // LBrace = 13
        unsafe {
            mut err: errors.CompilerError[Any];
            err.kind.tag = 1; // ParserError
            err.message = "Expected '{' after if condition";
            err.span = (*p).cur_token.span;
            (*p).errors.Push(err);
        }
        return empty[Index[ast.Statement[ctx], ctx]];
    }
    
    mut consequence := parse_block_statement(p, ctx);
    
    mut alternative := empty[Index[ast.BlockStatement[ctx], ctx]];
    mut end_span := ctx[consequence].span;
    
    unsafe {
        if cur_token_is(p, 36) { // Else = 36
            next_token(p); // consume 'else'
            if cur_token_is(p, 35) { // If = 35
                mut if_stmt := parse_if_statement(p, ctx);
                mut if_span := ctx[if_stmt].If.span;
                mut alt_statements: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
                alt_statements.Push(ctx[if_stmt]);
                mut alt_idx: Index[ast.BlockStatement[ctx], ctx] := os.ArenaAlloc(ctx);
                mut alt_statements_idx_parse: Index[std.Vector[ast.Statement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
                mut alt_block_parse: ast.BlockStatement[ctx];
                alt_block_parse.span = if_span;
                alt_block_parse.statements = alt_statements_idx_parse;
                ctx.Set(alt_statements_idx_parse, alt_statements);
                ctx.Set(alt_idx, alt_block_parse);
                alternative = alt_idx;
                end_span = if_span;
            } else {
                if cur_token_is(p, 13) { // LBrace = 13
                    alternative = parse_block_statement(p, ctx);
                    end_span = ctx[alternative].span;
                }
            }
        }
    }
    
    mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx); 
    unsafe {
        mut stmt_if_parse: ast.Statement[ctx];
        stmt_if_parse.tag = 7; // If = 7
        stmt_if_parse.If.condition = condition;
        stmt_if_parse.If.consequence = consequence;
        stmt_if_parse.If.alternative = alternative;
        stmt_if_parse.If.span = merge_spans(start_span, (*p).cur_token.span);
        ctx.Set(stmt_idx, stmt_if_parse);
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
    
    if cur_token_is(p, 13) == false { // LBrace = 13
        unsafe {
            mut err: errors.CompilerError[Any];
            err.kind.tag = 1; // ParserError
            err.message = "Expected '{' after else";
            err.span = (*p).cur_token.span;
            (*p).errors.Push(err);
        }
        return empty[Index[ast.Statement[ctx], ctx]];
    }
    
    mut else_body := parse_block_statement(p, ctx);
    
    mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        mut stmt_guard_parse: ast.Statement[ctx];
        stmt_guard_parse.tag = 9; // Guard = 9
        stmt_guard_parse.Guard.name = name;
        stmt_guard_parse.Guard.is_mut = is_mut;
        stmt_guard_parse.Guard.value = value;
        stmt_guard_parse.Guard.else_body = else_body;
        stmt_guard_parse.Guard.span = merge_spans(start_span, ctx[else_body].span);
        ctx.Set(stmt_idx, stmt_guard_parse);
    }
    return stmt_idx;
}

func parse_program(p: *Parser[ctx], ctx: &Arena) ast.Program[ctx] {
    mut prog: ast.Program[ctx];
    unsafe { 
        mut statements_vec: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
        mut dest_ptr := &statements_vec;
        
        mut start_span := (*p).cur_token.span;
        
        while (*p).cur_token.token_type.tag != 0 { // TokenType::Eof = 0
            mut before_errors := len((*p).errors);
            mut stmt := parse_statement(p, ctx);
            if stmt != empty[Index[ast.Statement[ctx], ctx]] {
                (*dest_ptr).Push(ctx[stmt]);
                if cur_token_is(p, 10) { // Semicolon = 10
                    next_token(p);
                }
            } else {
                if len((*p).errors) == before_errors {
                    error_at_current(p, "Syntax Error: unexpected token or malformed statement");
                }
                mut before_sync := (*p).cur_token.token_type.tag;
                synchronize(p);
                if (*p).cur_token.token_type.tag == before_sync {
                    next_token(p);
                }
            }
        }
        
        prog.statements = os.ArenaAlloc(ctx);
        ctx.Set(prog.statements, statements_vec);
        
        prog.span = merge_spans(start_span, (*p).cur_token.span);
    }
    return prog;
}

func parse_import_statement(p: *Parser[ctx], ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    unsafe {
        mut start_span := (*p).cur_token.span;
        if (*p).has_non_import_statement == 1 {
            mut err: errors.CompilerError[Any];
            err.kind.tag = 1; // ParserError
            err.message = "Imports must be at the beginning of the program";
            err.span = (*p).cur_token.span;
            (*p).errors.Push(err);
        }
        
        next_token(p); // consume 'import'
        
        if cur_token_is(p, 4) == false { // String = 4
            mut err: errors.CompilerError[Any];
            err.kind.tag = 1; // ParserError
            err.message = "Expected string literal specifying the import path";
            err.span = (*p).cur_token.span;
            (*p).errors.Push(err);
            return empty[Index[ast.Statement[ctx], ctx]];
        }
        
        mut path := std.Clone(*ctx, (*p).cur_token.literal);
        next_token(p); // consume string path
        
        mut alias := "";
        if cur_token_is(p, 37) { // As = 37
            next_token(p); // consume 'as'
            if cur_token_is(p, 2) == false { // Ident = 2
                mut err: errors.CompilerError[Any];
                err.kind.tag = 1; // ParserError
                err.message = "Expected identifier alias after 'as'";
                err.span = (*p).cur_token.span;
                (*p).errors.Push(err);
                return empty[Index[ast.Statement[ctx], ctx]];
            }
            alias = std.Clone(*ctx, (*p).cur_token.literal);
            next_token(p); // consume alias
        }
        
        mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        mut stmt_import_parse: ast.Statement[ctx];
        stmt_import_parse.tag = 0; // Import = 0
        stmt_import_parse.Import.path = path;
        stmt_import_parse.Import.alias = alias;
        stmt_import_parse.Import.span = merge_spans(start_span, (*p).cur_token.span);
        ctx.Set(stmt_idx, stmt_import_parse);
        return stmt_idx;
    }
}
