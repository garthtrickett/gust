type TaskArg[ctx] struct {
    val: int,
    flag: Index[int, ctx]
}

func task(arg: *TaskArg[ctx]) {
    unsafe {
        mut idx := (*arg).flag;
        mut ptr := &ctx[idx] as *int;
        *ptr = *ptr + (*arg).val;
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut flag_idx: Index[int, ctx] := os.ArenaAlloc(ctx);
    ctx[flag_idx] = 0;

    mut arg1: TaskArg[ctx];
    arg1.val = 10;
    arg1.flag = flag_idx;

    mut arg2: TaskArg[ctx];
    arg2.val = 20;
    arg2.flag = flag_idx;

    std.Spawn(task, &arg1);
    std.Spawn(task, &arg2);

    mut loop_active := 1;
    while loop_active == 1 {
        std.Yield();
        if ctx[flag_idx] == 30 {
            loop_active = 0;
        }
    }

    os.LogInt(ctx[flag_idx]);
}