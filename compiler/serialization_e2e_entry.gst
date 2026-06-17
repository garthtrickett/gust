
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        import "parser.gst" as parser;
        import "ast.gst" as ast;

        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut source := "import 'std' as standard;\ntype MyStruct struct {\n    val: int\n}\nfunc add(x: int) int {\n    return x + 1;\n}\nfunc main() {\n    mut x := 42;\n    while x < 50 {\n        x = x + 1;\n    }\n}";

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, source);

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            mut prog := parser.parse_program(&p, ctx);
            
            mut serialized := ast.serialize_program(&prog, 0, ctx);
            os.LogStr(serialized);
        }
    