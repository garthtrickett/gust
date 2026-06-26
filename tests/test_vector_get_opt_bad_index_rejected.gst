func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut vec: std.Vector[int, ctx] := std.VectorNew(ctx);
    vec.Push(10);

    mut bad_lookup := vec.get_opt("bad");
    match bad_lookup {
        Some { val } => {
            os.LogInt(*val);
        }
        None => {
            os.LogStr("None");
        }
    }
}