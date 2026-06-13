
        import "token.gst" as token;
        func main() {
            mut ctx1 := os.Arena.New();
            defer ctx1.Free();
            mut ctx2 := os.Arena.New();
            defer ctx2.Free();
            
            mut t1: token.Token[ctx1];
            mut t2: token.Token[ctx2] := t1;
        }
    