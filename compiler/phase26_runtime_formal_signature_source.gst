// A runtime import uses its declared Int formal for both accepted source types.
func emit_values(ctx: &Arena) {
    os.LogInt(1);
    os.LogInt(std.str_byte_at("A", 0));
    os.LogInt(true);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    emit_values(ctx);
}
