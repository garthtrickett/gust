type MyNode[ctx] struct {
    val: int
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut n1: Index[MyNode, ctx] := os.ArenaAlloc(ctx);
    ctx[n1].val = 42;
    
    unsafe {
        mut val_ptr := &ctx[n1].val;
        mut byte_ptr := val_ptr as *byte;
        *(byte_ptr + 8) = 0; // Corrupt post-canary of n1
    }
    
    os.ArenaValidate(ctx);
}