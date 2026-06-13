
        import "token.gst" as token;
        import "lexer.gst" as lexer;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut l: lexer.Lexer[ctx];
            lexer.init_lexer(&l, "mut a := 10;");
            
            mut t1 := lexer.next_token(&l);
            os.LogInt(t1.token_type.tag);
            os.LogStr(t1.literal);
            
            mut t2 := lexer.next_token(&l);
            os.LogInt(t2.token_type.tag);
            os.LogStr(t2.literal);
            
            mut t3 := lexer.next_token(&l);
            os.LogInt(t3.token_type.tag);
            os.LogStr(t3.literal);
            
            mut t4 := lexer.next_token(&l);
            os.LogInt(t4.token_type.tag);
            os.LogStr(t4.literal);
            
            mut t5 := lexer.next_token(&l);
            os.LogInt(t5.token_type.tag);
            os.LogStr(t5.literal);
        }
    