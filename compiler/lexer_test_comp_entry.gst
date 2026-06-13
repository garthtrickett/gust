
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, "mut a := 10;");
            mut t: token.Token[ctx];
            lexer.next_token(&l, &t);
        }
    