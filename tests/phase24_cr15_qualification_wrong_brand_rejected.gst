import "phase24_cr15_qualification_module.gst" as access;

type Counter struct {
    value: int
}

func main() int {
    mut first_arena := os.Arena.New();
    defer first_arena.Free();
    mut second_arena := os.Arena.New();
    defer second_arena.Free();
    mut mutex: std.Mutex[Counter, first_arena];
    mut owner: access.Lease[Counter, second_arena] := access.enter(&mutex);
    return 0;
}
