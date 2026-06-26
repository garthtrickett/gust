func check_some(ctx: &Arena) {
    mut opt_some: std.Option[int, ctx];
    unsafe {
        opt_some.tag = 0;
        opt_some.Some.val = 42;
    }

    match opt_some {
        Some { val } => {
            os.LogInt(val);
        }
        None => {
            os.LogStr("unexpected none");
        }
    }
}

func check_none(ctx: &Arena) {
    mut opt_none: std.Option[int, ctx];
    unsafe {
        opt_none.tag = 1;
    }

    match opt_none {
        Some { val } => {
            os.LogInt(val);
        }
        None => {
            os.LogStr("none");
        }
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    check_some(ctx);
    check_none(ctx);
}