func inspect(ctx: &Arena, values: std.HashMap[int, std.Vector[int, ctx], ctx]) {
    guard value := values.Get(1) else {
        return;
    }
    os.LogInt(len(value));
}

func main() {
}
