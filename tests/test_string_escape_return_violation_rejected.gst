func leak_view() str {
    mut local_ctx := os.Arena.New();
    defer local_ctx.Free();
    mut s := std.Concat("Hello ", "World", local_ctx);
    return s;
}
func main() {}
