type Counter struct {
    count: int
}
type ThreadArg[ctx] struct {
    mutex: std.Mutex[Counter, ctx]
}
func increment_task(arg: *ThreadArg[ctx]) {
    mut i := 0;
    while i < 100 {
        unsafe {
            mut val_ptr := (*arg).mutex.Lock();
            (*val_ptr).count = (*val_ptr).count + 1;
            (*arg).mutex.Unlock();
        }
        i = i + 1;
    }
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    
    mut m: std.Mutex[Counter, ctx] := std.MutexNew(ctx);
    unsafe {
        mut val := m.Lock();
        (*val).count = 0;
        m.Unlock();
    }

    mut arg: ThreadArg[ctx];
    arg.mutex = m;

    std.Spawn(increment_task, &arg);
    std.Spawn(increment_task, &arg);
    std.Spawn(increment_task, &arg);

    mut current_count := 0;
    while current_count < 300 {
        unsafe {
            mut val := arg.mutex.Lock();
            current_count = (*val).count;
            arg.mutex.Unlock();
        }
        std.Yield();
    }

    os.LogInt(current_count);
}