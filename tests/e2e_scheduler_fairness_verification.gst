type FairnessArg[arena] struct {
    flag: Index[int, arena],
    allocator: *Arena
}

func heavy_loop_task(arg: *FairnessArg[arena]) {
    mut running := 1;
    while running == 1 {
        unsafe {
            mut idx := (*arg).flag;
            mut arena := (*arg).allocator;
            mut ptr := &arena[idx] as *int;
            if *ptr == 1 {
                running = 0;
            }
        }
    }
    unsafe {
        mut idx := (*arg).flag;
        mut arena := (*arg).allocator;
        mut ptr := &arena[idx] as *int;
        *ptr = 2;
    }
}

func helper_task(arg: *FairnessArg[arena]) {
    unsafe {
        mut idx := (*arg).flag;
        mut arena := (*arg).allocator;
        mut ptr := &arena[idx] as *int;
        *ptr = 1;
    }
    os.LogStr("COOPERATIVE_FAIRNESS_SUCCEEDED");
}

func main() {
    mut arena := os.Arena.New();
    defer arena.Free();
    os.SetThreadScratch(&arena);

    mut flag_idx: Index[int, arena] := os.ArenaAlloc(arena);
    arena.Set(flag_idx, 0);

    mut arg: FairnessArg[arena];
    arg.flag = flag_idx;
    arg.allocator = &arena;

    std.Spawn(heavy_loop_task, &arg);
    std.Spawn(helper_task, &arg);

    mut loop_active := 1;
    while loop_active == 1 {
        std.Yield();
        if arena[flag_idx] == 2 {
            loop_active = 0;
        }
    }
}
