func main() {
    mut ctx := os.Arena.New();
    mut idx := os.ArenaAlloc(ctx);
    unsafe {
        mut ptr := &ctx[idx].SessionID;
        ctx.Free();
        os.LogInt(*ptr); // Heap use-after-free!
    }
}