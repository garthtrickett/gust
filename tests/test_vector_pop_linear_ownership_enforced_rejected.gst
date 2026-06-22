func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut vec: std.Vector[*int, ctx] := std.VectorNew(ctx);
    
    unsafe {
        mut val := 10;
        vec.Push(&val);
        
        mut p1 := vec.Pop();
        mut p2 := move p1;
        
        mut err := *p1;
    }
}