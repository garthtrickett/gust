import "phase24_cr15_qualification_module.gst" as access;

type Counter struct {
    value: int
}

func leak(mutex: &std.Mutex[Counter, ctx]) &Counter {
    mut owner := access.enter(mutex);
    return access.view(&owner);
}

func main() int {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut mutex: std.Mutex[Counter, arena];
    mut escaped := leak(&mutex);
    return 0;
}
