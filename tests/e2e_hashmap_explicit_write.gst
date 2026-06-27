func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut map: std.HashMap[int, int, ctx] := std.HashMapNew(ctx);
    map.Insert(1, 10);

    mut first_hit := map.Get(1);
    if first_hit.Ok {
        os.LogInt(first_hit.Val);
    } else {
        os.LogStr("missing first");
    }

    map.Set(1, 55);
    mut updated_hit := map.Get(1);
    if updated_hit.Ok {
        os.LogInt(updated_hit.Val);
    } else {
        os.LogStr("missing updated");
    }

    map.Set(2, 77);
    mut opt_hit := map.get_opt(2);
    match opt_hit {
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
