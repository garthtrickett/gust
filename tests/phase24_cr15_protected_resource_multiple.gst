import "stdlib_s1_mutex_guard_generic_derivation_module.gst" as sync;

type Counter struct {
    value: int
}

type Flag struct {
    value: bool
}

func main() int {
    mut first_arena := os.Arena.New();
    defer first_arena.Free();
    mut first: std.Mutex[Counter, first_arena] := std.MutexNew(&first_arena);
    mut first_guard := sync.lock(&first);
    mut first_value := sync.get(&first_guard);

    mut second_arena := os.Arena.New();
    defer second_arena.Free();
    mut second: std.Mutex[Flag, second_arena] := std.MutexNew(&second_arena);
    mut second_guard: sync.MutexGuard[Flag, second_arena] := sync.lock(&second);
    mut second_value := sync.get(&second_guard);

    mut third_arena := os.Arena.New();
    defer third_arena.Free();
    mut third: std.Mutex[Counter, third_arena] := std.MutexNew(&third_arena);
    mut third_guard := sync.lock(&third);
    mut third_value := sync.get(&third_guard);

    first_value.value = 7;
    second_value.value = true;
    third_value.value = 9;
    return first_value.value + third_value.value;
}
