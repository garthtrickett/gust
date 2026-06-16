type Counter struct {
    count: int
}

type Pipeline[ctx] struct {
    mutex: std.Mutex[Counter, ctx],
    chan: std.Channel[int, ctx]
}

func producer(p: *Pipeline[ctx]) { 
    mut i := 0;
    while i < 5 {
        unsafe {
            (*p).chan.Send(i);
        }
        i = i + 1;
    } 
}

func consumer(p: *Pipeline[ctx]) {
    mut i := 0;
    while i < 5 {
        mut val := 0;
        unsafe {
            val = (*p).chan.Recv();
            mut val_ptr := (*p).mutex.Lock();
            (*val_ptr).count = (*val_ptr).count + val;
            (*p).mutex.Unlock();
        }
        i = i + 1;
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut p: Pipeline[ctx];
    p.mutex = std.MutexNew(ctx);
    p.chan = std.ChannelNew(ctx);

    unsafe {
        mut val_ptr := p.mutex.Lock();
        (*val_ptr).count = 0;
        p.mutex.Unlock();
    }

    std.Spawn(producer, &p);
    std.Spawn(consumer, &p);

    mut loop_active := 1;
    while loop_active == 1 {
        std.Yield();
        unsafe {
            mut val_ptr := p.mutex.Lock();
            if (*val_ptr).count == 10 {
                loop_active = 0;
            }
            p.mutex.Unlock();
        }
    }

    unsafe {
        mut val_ptr := p.mutex.Lock();
        os.LogInt((*val_ptr).count); 
        p.mutex.Unlock();
    }
}
