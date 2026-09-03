import "phase24_cr15_qualification_no_metadata_module.gst" as access;

type Counter struct {
    value: int
}

func main() int {
    mut arena := os.Arena.New();
    defer arena.Free();
    mut mutex: std.Mutex[Counter, arena];
    mut owner := access.enter(&mutex);
    return 0;
}
