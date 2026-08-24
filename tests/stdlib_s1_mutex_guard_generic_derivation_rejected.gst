import "stdlib_s1_mutex_guard_generic_derivation_module.gst" as sync;

type Counter struct {
    value: int
}

func main() int {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut mutex: std.Mutex[Counter, arena] := std.MutexNew(&arena);
    mutex.value.value = 41;
    mut owner := sync.lock(&mutex);
    mut value := sync.get(&owner);
    value.value = value.value + 1;
    return value.value;
}
