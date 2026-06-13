import "token.gst" as token;
import "lexer.gst" as lexer;
import "errors.gst" as errors;

type ParseResult[T, ctx] struct {
    Ok: int,
    Val: T
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
        return (*p).cur_token.token_type.tag == tag;
    }
}

func peek_token_is(p: *Parser[ctx], tag: int) bool {
    unsafe {
        return (*p).peek_token.token_type.tag == tag;
    }
}

func expect_peek(p: *Parser[ctx], tag: int, ctx: &Arena) ParseResult[token.Token[ctx], ctx] {
    mut res: ParseResult[token.Token[ctx], ctx];
    unsafe {
        if (*p).peek_token.token_type.tag == tag {
            res.Ok = 1;
            res.Val = (*p).peek_token;
            next_token(p);
        } else {
            res.Ok = 0;
            
            mut err: errors.CompilerError[ctx];
            err.kind.tag = 1; // ParserError
            err.message = "Expected token tag";
            err.span = (*p).peek_token.span;
            
            (*p).errors.Push(err);
        }
    }
    return res;
}

func merge_spans(start: token.Span, end: token.Span) token.Span {
    mut s: token.Span;
    s.start = start.start;
    s.end = end.end;
    return s;
}