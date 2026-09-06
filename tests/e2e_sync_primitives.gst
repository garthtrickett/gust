import "stdlib_s1_mutex_guard_generic_derivation_module.gst" as sync;

type Counter struct {
    count: int
}

type Pipeline[ctx] struct {
    mutex: std.Mutex[Counter, ctx],
    chan: std.Channel[int, ctx]
}

// Each helper takes exactly one acquisition and releases it by scope exit.
// Migrated from manual Lock()/Unlock() pairs: there is no unlock call to
// forget, and no path out of these functions that skips it.
func set_count(mutex: &std.Mutex[Counter, ctx], value: int) {
    mut owner := sync.lock(mutex);
    mut counter := sync.get(&owner);
    counter.count = value;
}

func add_to_count(mutex: &std.Mutex[Counter, ctx], value: int) {
    mut owner := sync.lock(mutex);
    mut counter := sync.get(&owner);
    counter.count = counter.count + value;
}

func read_count(mutex: &std.Mutex[Counter, ctx]) int {
    mut owner := sync.lock(mutex);
    mut counter := sync.get(&owner);
    return counter.count;
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
            add_to_count(&(*p).mutex, val);
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

    set_count(&p.mutex, 0);

    std.Spawn(producer, &p);
    std.Spawn(consumer, &p);

    mut loop_active := 1;
    while loop_active == 1 {
        std.Yield();
        if read_count(&p.mutex) == 10 {
            loop_active = 0;
        }
    }

    os.LogInt(read_count(&p.mutex));
}
