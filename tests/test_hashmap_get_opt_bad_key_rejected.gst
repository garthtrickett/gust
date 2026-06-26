func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut map: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
    map.Insert(1, 100);

    mut bad_lookup := map.get_opt("bad");
    match bad_lookup {
        Some { val } => {
            os.LogInt(*val);
        }
        None => {
            os.LogStr("None");
        }
    }
}