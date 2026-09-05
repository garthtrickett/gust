import "stdlib_s1_mutex_guard_generic_derivation_module.gst" as sync;

type Counter struct {
    value: int
}

func main() int {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut mutex: std.Mutex[Counter, arena] := std.MutexNew(&arena);
    mut owner := sync.lock(&mutex);
    mut copied := owner;
    mut original_value := sync.get(&owner);
    mut copied_value := sync.get(&copied);
    return original_value.value + copied_value.value;
}
