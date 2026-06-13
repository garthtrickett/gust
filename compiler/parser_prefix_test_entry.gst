
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        import "parser.gst" as parser;
        import "ast.gst" as ast;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, "mut a := 10;");

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            mut expr := parser.parse_expression(&p, 1, ctx);
            
            os.LogInt(ctx[expr].tag);
            
            mut inner1 := ctx[expr].Dereference.expr;
            os.LogInt(ctx[inner1].tag);
            
            mut inner2 := ctx[inner1].AddressOf.expr;
            os.LogInt(ctx[inner2].tag);
            
            mut inner3 := ctx[inner2].Move.expr;
            os.LogInt(ctx[inner3].tag);
            os.LogStr(ctx[inner3].Identifier.name);
        }
    