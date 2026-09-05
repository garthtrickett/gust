import "stdlib_s1_mutex_guard_generic_derivation_module.gst" as sync;

type Counter struct {
    value: int
}

func main() int {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut mutex: std.Mutex[Counter, arena] := std.MutexNew(&arena);
    mut owner := sync.lock(&mutex);
    sync.release_mutex_guard(move owner);
    sync.release_mutex_guard(move owner);
    return 0;
}
