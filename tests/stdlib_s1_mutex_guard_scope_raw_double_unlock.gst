import "stdlib_s1_mutex_guard_generic_derivation_module.gst" as sync;

// Compile-only limitation witness. Never execute this program: the explicit
// unsafe unlock does not discharge the guard's registered scope cleanup.
type Counter struct {
    value: int
}

func main() int {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut mutex: std.Mutex[Counter, arena] := std.MutexNew(&arena);
    mut owner := sync.lock(&mutex);
    unsafe {
        mutex.Unlock();
    }
    return 0;
}
