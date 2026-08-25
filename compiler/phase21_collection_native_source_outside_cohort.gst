func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut values: std.Vector[int, ctx] := std.VectorNew(ctx);
    values.Push(10);
    values.Push(20);
    mut selected := values.get_opt(1);
    match selected {
        Some { val } => {
            unsafe { os.LogInt(*val); }
        }
        None => { os.LogStr("None"); }
    }
    os.LogInt(999);
}
