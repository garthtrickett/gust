import "phase24_cr15_qualification_module.gst" as access;

type Counter struct {
    value: int
}

type Flag struct {
    value: bool
}

func early_return(mutex: &std.Mutex[Counter, ctx]) int {
    mut lease: access.Lease[Counter, ctx] := access.enter(mutex);
    mut value: &Counter := access.view(&lease);
    return 7;
}

func break_exit(mutex: &std.Mutex[Counter, ctx]) int {
    while 1 {
        mut lease: access.Lease[Counter, ctx] := access.enter(mutex);
        break;
    }
    return 9;
}

func continue_exit(mutex: &std.Mutex[Counter, ctx]) int {
    mut iterations := 0;
    while iterations < 1 {
        iterations = iterations + 1;
        mut lease: access.Lease[Counter, ctx] := access.enter(mutex);
        continue;
    }
    return 10;
}

func main() int {
    mut first_arena := os.Arena.New();
    defer first_arena.Free();
    mut first: std.Mutex[Counter, first_arena] := std.MutexNew(&first_arena);
    first.value.value = 2;
    os.LogInt(early_return(&first));
    os.LogInt(break_exit(&first));
    os.LogInt(continue_exit(&first));

    if 1 {
        mut second: std.Mutex[Flag, first_arena] := std.MutexNew(&first_arena);
        mut second_lease: access.Lease[Flag, first_arena] := access.enter(&second);
        mut second_access: &Flag := access.view(&second_lease);
    }

    mut third_arena := os.Arena.New();
    defer third_arena.Free();
    mut third: std.Mutex[Counter, third_arena] := std.MutexNew(&third_arena);
    third.value.value = 3;
    if 1 {
        mut source: access.Lease[Counter, third_arena] := access.enter(&third);
        mut destination: access.Lease[Counter, third_arena] := move source;
        mut third_access: &Counter := access.view(&destination);
        third_access.value = third_access.value + 4;
        os.LogInt(third_access.value);
    }

    mut repeated: access.Lease[Counter, third_arena] := access.enter(&third);
    mut repeated_access: &Counter := access.view(&repeated);
    repeated_access.value = repeated_access.value + 1;
    os.LogInt(repeated_access.value);
    return 0;
}
