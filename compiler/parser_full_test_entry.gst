
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        import "parser.gst" as parser;
        import "ast.gst" as ast;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            // 1. Parse a function declaration
            mut l1: lexer.Lexer[ctx];
            lexer.init_lexer(&l1, "func add(x: int, y: int) int { return x + y; }");
            mut p1: parser.Parser[ctx];
            parser.init_parser(&p1, &l1, ctx);
            mut stmt1 := parser.parse_statement(&p1, ctx);
            os.LogInt(ctx[stmt1].tag);
            os.LogStr(ctx[stmt1].FunctionDecl.name);

            // 2. Parse a match statement
            mut l2: lexer.Lexer[ctx];
            lexer.init_lexer(&l2, "match shape { Circle { radius } => { return 1; }, Point => { return 2; } }");
            mut p2: parser.Parser[ctx];
            parser.init_parser(&p2, &l2, ctx);
            mut stmt2 := parser.parse_statement(&p2, ctx);
            os.LogInt(ctx[stmt2].tag);

            // 3. Parse a defer statement
            mut l3: lexer.Lexer[ctx];
            lexer.init_lexer(&l3, "defer ctx.Free();");
            mut p3: parser.Parser[ctx];
            parser.init_parser(&p3, &l3, ctx);
            mut stmt3 := parser.parse_statement(&p3, ctx);
            os.LogInt(ctx[stmt3].tag);

            // 4. Parse an unsafe block
            mut l4: lexer.Lexer[ctx];
            lexer.init_lexer(&l4, "unsafe { return; }");
            mut p4: parser.Parser[ctx];
            parser.init_parser(&p4, &l4, ctx);
            mut stmt4 := parser.parse_statement(&p4, ctx);
            os.LogInt(ctx[stmt4].tag);
        }
    