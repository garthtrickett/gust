func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut path := "phase21-filesystem-outside.txt";
    mut wrote := os.WriteFile(path, std.Concat("phase", "20"));
    os.LogInt(wrote);
    mut contents := os.ReadFile(ctx, path);
    os.LogStr(contents);
}
