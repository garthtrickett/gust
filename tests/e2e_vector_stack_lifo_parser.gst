func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    
    mut stack: std.Vector[int, ctx] := std.VectorNew(ctx);
    stack.Push(10);
    stack.Push(20);
    stack.Push(30);
    
    // Inspect the tail with Back
    unsafe {
        mut top := stack.Back();
        os.LogInt(*top);
        
        // Mutate in-place
        *top = 35;
    }
    
    // Pop off in LIFO order
    os.LogInt(stack.Pop());
    os.LogInt(stack.Pop());
    
    // Push another
    stack.Push(40);
    os.LogInt(len(stack));
    
    // Clear the stack
    stack.Clear();
    os.LogInt(len(stack));
}