type Phase20Counter struct {
    value: int
}

type Phase20ThreadArg[ctx] struct {
    mutex: std.Mutex[Phase20Counter, ctx]
}

func phase20_increment(arg: *Phase20ThreadArg[ctx]) {
    unsafe {
        mut value := (*arg).mutex.Lock();
        (*value).value = (*value).value + 1;
        (*arg).mutex.Unlock();
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut mutex: std.Mutex[Phase20Counter, ctx] := std.MutexNew(ctx);
    mut arg: Phase20ThreadArg[ctx];
    arg.mutex = mutex;
    std.Spawn(phase20_increment, &arg);
    std.Yield();
}
