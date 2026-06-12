
        import "token.gst" as token;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            mut t: token.Token[ctx];
            t.token_type = token.TokenType.Ident;
            t.literal = "hello";
        }
    