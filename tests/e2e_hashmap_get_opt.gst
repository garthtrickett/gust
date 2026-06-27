func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut map: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
    map.Insert(7, 700);

    mut hit := map.get_opt(7);
    match hit {
        Some { val } => {
            unsafe {
                os.LogInt(*val);
            }
        }
        None => {
            os.LogStr("None");
        }
    }

    mut miss := map.get_opt(42);
    match miss {
        Some { val } => {
            unsafe {
                os.LogInt(*val);
            }
        }
        None => {
            os.LogStr("None");
        }
    }
}
