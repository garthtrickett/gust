func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut map_ref_test: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
    map_ref_test.Insert("alpha", 10);
    map_ref_test.Insert("beta", 20);

    mut alpha_ref := map_ref_test.GetRef("alpha");
    unsafe {
        os.LogInt(*alpha_ref);

        *alpha_ref = *alpha_ref + 5;
    }

    mut legacy_after_ref := map_ref_test.Get("alpha");
    if legacy_after_ref.Ok {
        os.LogInt(legacy_after_ref.Val);
    } else {
        os.LogStr("missing");
    }

    mut beta_opt_after_ref := map_ref_test.get_opt("beta");
    match beta_opt_after_ref {
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
