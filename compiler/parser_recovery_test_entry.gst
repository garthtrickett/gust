
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        import "parser.gst" as parser;
        import "ast.gst" as ast;
        
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, "type MyStruct struct { field: } func main() {}");

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            mut prog := parser.parse_program(&p, ctx);
            os.LogInt(len(p.errors)); // Expected: 1
            unsafe {
                mut statements_ptr := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
                os.LogInt((*statements_ptr).len); // Expected: 1
                if (*statements_ptr).len > 0 {
                    mut main_stmt := (*statements_ptr)[0];
                    os.LogInt(main_stmt.tag); // Expected: 3 (FunctionDecl)
                    os.LogStr(main_stmt.FunctionDecl.name); // Expected: main
                }
            }
        }
    