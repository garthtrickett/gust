func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut opt_wrong_field: std.Option[int, ctx];
    unsafe {
        opt_wrong_field.tag = 0;
        opt_wrong_field.Some.val = 11;
    }

    match opt_wrong_field {
        Some { wrong } => {
            unsafe {
                os.LogInt(*wrong);
            }
        }
        None => {
            os.LogStr("none");
        }
    }
}
