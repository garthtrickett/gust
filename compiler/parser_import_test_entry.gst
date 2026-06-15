
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        import "parser.gst" as parser;
        import "ast.gst" as ast;
        
        func test_valid() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, "import 'token.gst' as token;\nimport 'lexer.gst';\nmut x := 42;");

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            mut prog := parser.parse_program(&p, ctx);
            os.LogInt(len(p.errors)); // Expected: 0
            unsafe {
                    mut statements_ptr := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
                    os.LogInt((*statements_ptr).len); // Expected: 3
            }
        }

        func test_misplaced() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, "mut x := 42;\nimport 'token.gst';");

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            mut prog := parser.parse_program(&p, ctx);
            os.LogInt(len(p.errors)); // Expected: 1
        }

        func main() {
            test_valid();
            test_misplaced();
        }
    