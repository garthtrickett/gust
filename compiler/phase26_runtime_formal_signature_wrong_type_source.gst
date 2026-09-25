// The formal Int ABI must not turn an incompatible Str argument into a call.
func emit_invalid(ctx: &Arena) {
    os.LogInt("invalid");
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    emit_invalid(ctx);
}
