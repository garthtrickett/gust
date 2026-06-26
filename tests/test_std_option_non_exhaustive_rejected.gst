func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut opt_missing: std.Option[int, ctx];
    unsafe {
        opt_missing.tag = 0;
        opt_missing.Some.val = 7;
    }

    match opt_missing {
        Some => {
            unsafe {
                os.LogInt(opt_missing.Some.val);
            }
        }
    }
}
