import "stdlib_s1_mutex_guard_generic_derivation_module.gst" as sync;

type Counter struct {
    value: int
}

func main() int {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut mutex: std.Mutex[Counter, arena] := std.MutexNew(&arena);
    mut source := sync.lock(&mutex);
    mut destination := move source;
    mut invalid := sync.get(&source);
    mut valid := sync.get(&destination);
    return invalid.value + valid.value;
}
