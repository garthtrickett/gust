
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        import "parser.gst" as parser;
        import "ast.gst" as ast;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, "type MyStruct[T] struct { x: int, y: bool }");

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            mut stmt := parser.parse_statement(&p, ctx);
            os.LogInt(ctx[stmt].tag);
            os.LogStr(ctx[stmt].StructDecl.name);
            
            mut l2: lexer.Lexer[ctx];
            lexer.init_lexer(&l2, "type MyEnum enum { Circle { r: int }, Point }");
            
            mut p2: parser.Parser[ctx];
            parser.init_parser(&p2, &l2, ctx);
            
            mut stmt2 := parser.parse_statement(&p2, ctx);
            os.LogInt(ctx[stmt2].tag);
            os.LogStr(ctx[stmt2].EnumDecl.name);
        }
    