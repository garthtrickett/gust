// Direct calls must preserve the by-value string view across both ABI positions.
func phase26_str_size(value: str) int {
    return len(value);
}

func phase26_str_identity(value: str) str {
    return value;
}

func phase26_str_clone(ctx: &Arena, value: str) str {
    return std.Clone(ctx, value);
}

func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    os.LogInt(phase26_str_size("native view"));
    os.LogStr(phase26_str_identity("direct return"));
    os.LogStr(phase26_str_clone(ctx, "cloned return"));
    return 0;
}
