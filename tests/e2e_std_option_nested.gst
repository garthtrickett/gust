func check_nested_some(ctx: &Arena) {
    mut nested_some: std.Option[std.Option[int, ctx], ctx];
    unsafe {
        nested_some.tag = 0;
        nested_some.Some.val.tag = 0;
        nested_some.Some.val.Some.val = 88;
    }

    match nested_some {
        Some { val } => {
            unsafe {
                match *val {
                    Some => {
                        os.LogInt((*val).Some.val);
                    }
                    None => {
                        os.LogStr("inner none");
                    }
                }
            }
        }
        None => {
            os.LogStr("outer none");
        }
    }
}

func check_nested_none(ctx: &Arena) {
    mut nested_none: std.Option[std.Option[int, ctx], ctx];
    unsafe {
        nested_none.tag = 1;
    }

    match nested_none {
        Some { val } => {
            unsafe {
                match *val {
                    Some => {
                        os.LogInt((*val).Some.val);
                    }
                    None => {
                        os.LogStr("inner none");
                    }
                }
            }
        }
        None => {
            os.LogStr("outer none");
        }
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    check_nested_some(ctx);
    check_nested_none(ctx);
}
