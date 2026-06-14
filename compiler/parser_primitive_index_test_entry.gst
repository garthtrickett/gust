
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        import "parser.gst" as parser;
        import "ast.gst" as ast;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();

            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, "Index[str, ctx]");

            mut p: parser.Parser[ctx];
            parser.init_parser(&p, &l, ctx);

            mut t_sig := parser.parse_type_signature(&p, ctx);
            
            os.LogInt(ctx[t_sig].tag); // Expected: 7 (Index)
            os.LogStr(ctx[t_sig].Index.struct_name); // Expected: str
            
            mut l2: lexer.Lexer[ctx];
            lexer.init_lexer(&l2, "Index[int, ctx]");
            
            mut p2: parser.Parser[ctx];
            parser.init_parser(&p2, &l2, ctx);
            
            mut t_sig2 := parser.parse_type_signature(&p2, ctx);
            os.LogStr(ctx[t_sig2].Index.struct_name); // Expected: int

            mut l3: lexer.Lexer[ctx];
            lexer.init_lexer(&l3, "Index[std.Vector[int, ctx], ctx]");
            
            mut p3: parser.Parser[ctx];
            parser.init_parser(&p3, &l3, ctx);
            
            mut t_sig3 := parser.parse_type_signature(&p3, ctx);
            os.LogStr(ctx[t_sig3].Index.struct_name); // Expected: std_Vector_int_ctx
        }
    