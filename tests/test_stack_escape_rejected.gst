func leak() str {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut tl: std.ThreadLocalContext[ctx] := os.GetThreadScratch();
    unsafe {
        mut ptr := tl.arena as []byte;
        mut s := ptr as str;
        return s;
    }
}

func main() {}