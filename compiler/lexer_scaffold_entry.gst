
        import "lexer.gst" as lexer;
        func main() {
            mut ctx := os.Arena.New();
            defer ctx.Free();
            
            mut l := lexer.new_lexer("   a", ctx);
            os.LogInt(l.ch as int);
            
            lexer.skip_whitespace(&l);
            os.LogInt(l.ch as int);
        }
    