func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut vec: std.Vector[int, ctx] := std.VectorNew(ctx);
    vec.Push(10);
    vec.Push(20);
    vec.Push(30);

    mut hit := vec.get_opt(1);
    match hit {
        Some { val } => {
            os.LogInt(*val);
        }
        None => {
            os.LogStr("None");
        }
    }

    mut miss := vec.get_opt(99);
    match miss {
        Some { val } => {
            os.LogInt(*val);
        }
        None => {
            os.LogStr("None");
        }
    }
}