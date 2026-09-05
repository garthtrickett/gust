import "stdlib_s1_mutex_guard_generic_derivation_module.gst" as sync;

type Counter struct {
    value: int
}

type OwnerPair[ctx] struct {
    first: sync.MutexGuard[Counter, ctx],
    second: sync.MutexGuard[Counter, ctx]
}

func main() int {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut mutex: std.Mutex[Counter, arena] := std.MutexNew(&arena);
    mut owner := sync.lock(&mutex);
    mut pair: OwnerPair[arena];
    pair.first = move owner;
    pair.second = move owner;
    return 0;
}
