import "phase20_protected_access_module.gst" as protected;

func live_access() int {
    mut value: protected.ProtectedValue[ctx];
    value.value = 37;
    mut owner := protected.acquire(&value, 1);
    mut view := protected.access(&owner);
    mut observed := view.value;
    protected.consume(owner);
    return observed;
}

func moved_guard_access() int {
    mut value: protected.ProtectedValue[ctx];
    value.value = 5;
    mut owner := protected.acquire(&value, 2);
    mut moved := owner;
    mut view := protected.access(&moved);
    mut observed := view.value;
    protected.consume(moved);
    return observed;
}

func normal_scope_cleanup() {
    mut value: protected.ProtectedValue[ctx];
    value.value = 9;
    mut owner := protected.acquire(&value, 3);
    mut view := protected.access(&owner);
    os.LogInt(view.value);
}

func early_return_cleanup() int {
    mut value: protected.ProtectedValue[ctx];
    value.value = 11;
    mut owner := protected.acquire(&value, 4);
    mut view := protected.access(&owner);
    return view.value;
}

func conditional_cleanup() {
    if 1 {
        mut value: protected.ProtectedValue[ctx];
        value.value = 13;
        mut owner := protected.acquire(&value, 5);
        mut view := protected.access(&owner);
        os.LogInt(view.value);
    }
}

func failure_cleanup(ctx: &Arena) int {
    mut value: protected.ProtectedValue[ctx];
    value.value = 17;
    mut owner := protected.acquire(&value, 6);
    mut view := protected.access(&owner);
    guard directory := os.OpenDir(ctx, "/phase20-protected-access-missing") else {
        return view.value;
    }
    os.CloseDir(directory);
    return 0;
}

func mutex_normal_cleanup(mutex: &std.Mutex[protected.ProtectedValue[ctx], ctx]) {
    mut owner := protected.acquire_mutex_owner(mutex, 21);
    mut view := protected.mutex_access(&owner);
    os.LogInt(view.value);
}

func mutex_early_cleanup(mutex: &std.Mutex[protected.ProtectedValue[ctx], ctx]) int {
    mut owner := protected.acquire_mutex_owner(mutex, 22);
    return 1;
}

func mutex_conditional_cleanup(mutex: &std.Mutex[protected.ProtectedValue[ctx], ctx]) {
    if 1 {
        mut owner := protected.acquire_mutex_owner(mutex, 23);
    }
}

func mutex_failure_cleanup(mutex: &std.Mutex[protected.ProtectedValue[ctx], ctx], arena: &Arena) int {
    mut owner := protected.acquire_mutex_owner(mutex, 24);
    guard directory := os.OpenDir(arena, "/phase20-protected-access-missing") else {
        return 1;
    }
    os.CloseDir(directory);
    return 0;
}

func main() int {
    mut observed := live_access() + moved_guard_access();
    normal_scope_cleanup();
    observed = observed + early_return_cleanup();
    conditional_cleanup();
    mut ctx := os.Arena.New();
    observed = observed + failure_cleanup(ctx);
    mut mutex: std.Mutex[protected.ProtectedValue[ctx], ctx] := std.MutexNew(ctx);
    mutex_normal_cleanup(&mutex);
    observed = observed + mutex_early_cleanup(&mutex);
    mutex_conditional_cleanup(&mutex);
    observed = observed + mutex_failure_cleanup(&mutex, ctx);
    ctx.Free();
    os.LogInt(observed);
    return observed;
}
