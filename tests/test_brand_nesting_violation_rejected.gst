func accept_context(ctx: &Arena, tl: std.ThreadLocalContext[ctx]) {
}

func main() {
 mut ctx1 := os.Arena.New();
 defer ctx1.Free();
 mut ctx2 := os.Arena.New();
 defer ctx2.Free();
 
 mut tl: std.ThreadLocalContext[ctx1] := os.GetThreadScratch();
 accept_context(ctx2, tl);
}