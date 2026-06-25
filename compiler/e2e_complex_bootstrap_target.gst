type Status enum {
    Pending,
    Active { name: str },
    Completed { duration: int }
}

type TaskResult[T, ctx] enum {
    Ok { val: T },
    Err { message: str }
}

type SharedState struct {
    count: int
}

type Pipeline[ctx] struct {
    mutex: std.Mutex[SharedState, ctx],
    chan: std.Channel[int, ctx]
}

func producer(p: *Pipeline[ctx]) {
    mut i := 0;
    while i < 3 {
        unsafe {
            (*p).chan.Send(i);
        }
        i = i + 1;
    }
}

func consumer(p: *Pipeline[ctx]) {
    mut i := 0;
    while i < 3 {
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

    // 1. ADT / Match testing
    mut s: Status;
    s.tag = 1; // Active
    s.Active.name = "E2E_Bootstrap";

    match s {
        Pending => {
            os.LogStr("Pending");
        }
        Active { name } => {
            mut msg := std.Concat("Active: ", *name);
            os.LogStr(msg);
        }
        Completed { duration } => {
            os.LogStr("Completed");
        }
    }

    // 2. Cooperative Fibers + Sync testing
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
            if (*val_ptr).count == 3 {
                loop_active = 0;
            }
            p.mutex.Unlock();
        }
    }

    unsafe {
        mut val_ptr := p.mutex.Lock();
        os.LogInt((*val_ptr).count); // Expected: 3
        p.mutex.Unlock();
    }

    // 3. Directory iteration testing
    mut opt_dir := os.OpenDir(ctx, "compiler");
    if opt_dir.Ok {
        mut d := opt_dir.Val;
        mut found_parser := 0;
        mut loop_active_dir := 1;
        while loop_active_dir == 1 {
            mut opt_entry := os.ReadDir(ctx, d);
            if opt_entry.Ok {
                mut name := opt_entry.Val.name;
                if std.str_eq(name, "parser.gst") {
                    found_parser = 1;
                }
            } else {
                loop_active_dir = 0;
            }
        }
        os.CloseDir(d);
        os.LogInt(found_parser); // Expected: 1
    }
}
