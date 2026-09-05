import "stdlib_s1_mutex_guard_generic_derivation_module.gst" as sync;

type Counter struct {
    value: int
}

func observe(mutex: &std.Mutex[Counter, ctx]) int {
    mut owner := sync.lock(mutex);
    mut value := sync.get(&owner);
    return value.value;
}

func normal_scope(mutex: &std.Mutex[Counter, ctx]) {
    mut owner := sync.lock(mutex);
    mut value := sync.get(&owner);
    value.value = value.value + 1;
}

func early_return(mutex: &std.Mutex[Counter, ctx]) int {
    mut owner := sync.lock(mutex);
    mut value := sync.get(&owner);
    value.value = value.value + 1;
    return value.value;
}

func nested_scope(mutex: &std.Mutex[Counter, ctx]) int {
    mut observed := 0;
    if 1 {
        mut owner := sync.lock(mutex);
        mut value := sync.get(&owner);
        value.value = value.value + 1;
        observed = value.value;
    }
    return observed;
}

func error_return(mutex: &std.Mutex[Counter, ctx], arena: &Arena) int {
    mut owner := sync.lock(mutex);
    mut value := sync.get(&owner);
    value.value = value.value + 1;
    guard directory := os.OpenDir(arena, "/gust-s1-9-missing-directory") else {
        return value.value;
    }
    os.CloseDir(directory);
    return value.value;
}

func moved_guard(mutex: &std.Mutex[Counter, ctx]) int {
    mut source := sync.lock(mutex);
    mut destination := move source;
    mut value := sync.get(&destination);
    value.value = value.value + 1;
    return value.value;
}

func increment_in_helper(owner: sync.MutexGuard[Counter, ctx]) int {
    mut value := sync.get(&owner);
    value.value = value.value + 1;
    return value.value;
}

func passed_guard(mutex: &std.Mutex[Counter, ctx]) int {
    mut owner := sync.lock(mutex);
    return increment_in_helper(move owner);
}

func returned_guard(mutex: &std.Mutex[Counter, ctx]) sync.MutexGuard[Counter, ctx] {
    return sync.lock(mutex);
}

func use_returned_guard(mutex: &std.Mutex[Counter, ctx]) int {
    mut owner := returned_guard(mutex);
    mut value := sync.get(&owner);
    value.value = value.value + 1;
    return value.value;
}

func main() int {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut mutex: std.Mutex[Counter, arena] := std.MutexNew(&arena);
    mutex.value.value = 0;

    normal_scope(&mutex);
    os.LogInt(observe(&mutex));
    os.LogInt(early_return(&mutex));
    os.LogInt(nested_scope(&mutex));
    os.LogInt(error_return(&mutex, &arena));
    os.LogInt(moved_guard(&mutex));
    os.LogInt(passed_guard(&mutex));
    os.LogInt(use_returned_guard(&mutex));
    os.LogInt(observe(&mutex));
    return 0;
}
