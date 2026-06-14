
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        import "parser.gst" as parser;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, "mut a := 10;");

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            parser.next_token(&p);

            mut is_mut := parser.cur_token_is(&p, 29); // Mut = 29
            mut is_ident := parser.peek_token_is(&p, 2); // Ident = 2

            guard tok := parser.expect_peek(&p, 2, ctx) else {
                return;
            }

            mut s := parser.merge_spans(p.cur_token.span, tok.span);
        }
    