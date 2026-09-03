import "phase24_cr15_qualification_module.gst" as access;

type Counter struct {
    value: int
}

func main() int {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut mutex: std.Mutex[Counter, arena];
    mut forged: access.Lease[Counter, arena];
    forged.mutex = &mutex;
    return 0;
}
