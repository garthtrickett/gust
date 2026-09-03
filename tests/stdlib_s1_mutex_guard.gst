import "stdlib_s1_mutex_guard_generic_derivation_module.gst" as sync;

type Counter struct {
    value: int
}

func increment(mutex: &std.Mutex[Counter, ctx]) int {
    mut owner := sync.lock(mutex);
    mut value := sync.get(&owner);
    value.value = value.value + 1;
    return value.value;
}

func main() int {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut mutex: std.Mutex[Counter, arena] := std.MutexNew(&arena);
    mutex.value.value = 40;

    // Returning from increment releases the first owner. The second call must
    // therefore acquire the same mutex successfully rather than deadlocking.
    os.LogInt(increment(&mutex));
    os.LogInt(increment(&mutex));
    return 0;
}
