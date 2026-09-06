import "stdlib_s1_mutex_guard_generic_derivation_module.gst" as sync;

type Counter struct {
    count: int
}

type ThreadArg[ctx] struct {
    mutex: std.Mutex[Counter, ctx]
}

// One acquisition per call, released by scope exit rather than by an explicit
// unlock. Every mutation below goes through this, so the guard is the only
// path to the protected value.
func increment_once(mutex: &std.Mutex[Counter, ctx]) {
    mut owner := sync.lock(mutex);
    mut value := sync.get(&owner);
    value.count = value.count + 1;
}

func observe(mutex: &std.Mutex[Counter, ctx]) int {
    mut owner := sync.lock(mutex);
    mut value := sync.get(&owner);
    return value.count;
}

// Holds the guard across a suspension point. A contending fiber must suspend
// here and wake only once this call returns and the guard leaves scope.
func hold_across_yield(mutex: &std.Mutex[Counter, ctx]) {
    mut owner := sync.lock(mutex);
    mut value := sync.get(&owner);
    value.count = value.count + 1;
    std.Yield();
    std.Yield();
}

// The `unsafe` blocks below scope the *spawn argument* dereference, which is
// the pre-existing raw-pointer fiber ABI. They are not mutex operations: every
// acquisition still goes through the safe `sync.lock` / `sync.get` surface, and
// this file contains no raw `Mutex.Lock` or `Mutex.Unlock` call.
func holder_task(arg: *ThreadArg[ctx]) {
    unsafe {
        hold_across_yield(&(*arg).mutex);
    }
}

func contender_task(arg: *ThreadArg[ctx]) {
    unsafe {
        increment_once(&(*arg).mutex);
    }
}

func increment_task(arg: *ThreadArg[ctx]) {
    mut i := 0;
    while i < 100 {
        unsafe {
            increment_once(&(*arg).mutex);
        }
        i = i + 1;
    }
}

func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut m: std.Mutex[Counter, ctx] := std.MutexNew(&ctx);
    m.value.count = 0;

    mut arg: ThreadArg[ctx];
    arg.mutex = m;

    // Contention, suspension and wakeup: the holder takes the guard and yields
    // while still holding it; the contender cannot proceed until scope exit
    // releases it. Both increments must land, so the count is exactly 2.
    std.Spawn(holder_task, &arg);
    std.Spawn(contender_task, &arg);

    mut settled := 0;
    while settled < 2 {
        settled = observe(&arg.mutex);
        std.Yield();
    }
    os.LogInt(settled);

    // Many fibers incrementing a shared integer through the guard. Three
    // fibers times one hundred increments, on top of the two above, is exactly
    // 302. Any lost update from a dropped acquisition would hang this loop
    // rather than print a wrong number.
    std.Spawn(increment_task, &arg);
    std.Spawn(increment_task, &arg);
    std.Spawn(increment_task, &arg);

    mut total := 0;
    while total < 302 {
        total = observe(&arg.mutex);
        std.Yield();
    }
    os.LogInt(total);
    return 0;
}
