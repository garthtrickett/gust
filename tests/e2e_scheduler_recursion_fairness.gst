type RecurseArg[arena] struct {
    flag: Index[int, arena],
    allocator: *Arena
}

func deep_recurse_task(arg: *RecurseArg[arena]) {
    unsafe {
        mut idx := (*arg).flag;
        mut arena := (*arg).allocator;
        mut ptr := &arena[idx] as *int;
        if *ptr == 1 {
            return;
        }
    }
    deep_recurse_task(arg);
}

func helper_task_rec(arg: *RecurseArg[arena]) {
    unsafe {
        mut idx := (*arg).flag;
        mut arena := (*arg).allocator;
        mut ptr := &arena[idx] as *int;
        *ptr = 1;
    }
    os.LogStr("RECURSION_FAIRNESS_SUCCEEDED");
}

func main() {
    mut arena := os.Arena.New();
    defer arena.Free();
    os.SetThreadScratch(&arena);

    mut flag_idx: Index[int, arena] := os.ArenaAlloc(arena);
    arena[flag_idx] = 0;

    mut arg: RecurseArg[arena];
    arg.flag = flag_idx;
    arg.allocator = &arena;

    std.Spawn(deep_recurse_task, &arg);
    std.Spawn(helper_task_rec, &arg);

    mut loop_active := 1;
    while loop_active == 1 {
        std.Yield();
        if arena[flag_idx] == 1 {
            loop_active = 0;
        }
    }
}