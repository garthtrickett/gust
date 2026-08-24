type Counter struct {
    value: int
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut mutex: std.Mutex[Counter, ctx] := std.MutexNew(ctx);
    mut value := mutex.Lock();
}
