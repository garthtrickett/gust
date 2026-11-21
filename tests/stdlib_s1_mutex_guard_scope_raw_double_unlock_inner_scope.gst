import "stdlib_s1_mutex_guard_generic_derivation_module.gst" as sync;

// Lexical-scope successor proposal. Compile only; NEVER execute this program.
// Explicit unsafe unlock still does not discharge registered owner cleanup.
type Counter struct {
    value: int
}

func main() int {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut mutex: std.Mutex[Counter, arena] := std.MutexNew(&arena);
    // Finish owner cleanup in this inner scope before outer arena.Free.
    if 1 {
        mut owner := sync.lock(&mutex);
        unsafe {
            mutex.Unlock();
        }
    }
    return 0;
}
