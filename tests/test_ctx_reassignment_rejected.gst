func process(ctx: &Arena) {
    mut other := os.Arena.New();
    defer other.Free();
    ctx = &other;
}

func main() {}
func process(ctx: &Arena) {
    mut other := os.Arena.New();
    defer other.Free();
    ctx = &other;
}

func main() {}
