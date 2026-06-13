
        import "lexer.gst" as lexer;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, "identifier 12345 \"string\"");
            
            mut ident: str := lexer.read_identifier(&l);
            lexer.skip_whitespace(&l);
            mut num: str := lexer.read_number(&l);
            lexer.skip_whitespace(&l);
            mut s: str := lexer.read_string(&l);
            
            os.LogStr(ident);
            os.LogStr(num);
            os.LogStr(s);
        }
    