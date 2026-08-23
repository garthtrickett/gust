// Compile-fail: an explicit collection annotation cannot rewrite the arena
// identity of a value returned by a helper.
func make_channel(ctx: &Arena) std.Channel[int, ctx] {
    return std.ChannelNew(ctx);
}

func main() {
    mut source_arena := os.Arena.New();
    defer source_arena.Free();
    mut destination_arena := os.Arena.New();
    defer destination_arena.Free();

    mut wrong: std.Channel[int, destination_arena] := make_channel(&source_arena);
}
