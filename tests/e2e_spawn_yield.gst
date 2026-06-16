type TaskArg[arena] struct {
    val: int,
    flag: Index[int, arena]
}

func task(arg: *TaskArg[arena]) { 
    unsafe {
        mut idx := (*arg).flag;
        mut tl := os.GetThreadScratch();
        mut arena: &Arena := tl.arena;
        mut ptr := &arena[idx] as *int;
        *ptr = *ptr + (*arg).val;
    }
}

func main() {
    mut arena := os.Arena.New();
    defer arena.Free();
    os.SetThreadScratch(arena);

    mut flag_idx: Index[int, arena] := os.ArenaAlloc(arena);
    arena[flag_idx] = 0;

    mut arg1: TaskArg[arena];
    arg1.val = 10;
    arg1.flag = flag_idx;

    mut arg2: TaskArg[arena];
    arg2.val = 20;
    arg2.flag = flag_idx;

    std.Spawn(task, &arg1);
    std.Spawn(task, &arg2);

    mut loop_active := 1;
    while loop_active == 1 {
        std.Yield();
        if arena[flag_idx] == 30 {
            loop_active = 0;
        }
    }

    os.LogInt(arena[flag_idx]);
}
