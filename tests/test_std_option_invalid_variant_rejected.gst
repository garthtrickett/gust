func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut opt_invalid_variant: std.Option[int, ctx];
    unsafe {
        opt_invalid_variant.tag = 0;
        opt_invalid_variant.Some.val = 5;
    }

    match opt_invalid_variant {
        Some { val } => {
            os.LogInt(*val);
        }
        Missing => {
            os.LogStr("missing");
        }
        None => {
            os.LogStr("none");
        }
    }
}