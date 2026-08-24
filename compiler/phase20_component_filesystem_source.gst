func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut path := "phase20-component-file.txt";
    mut wrote := os.WriteFile(path, "phase20");
    os.LogInt(wrote);
    mut contents := os.ReadFile(ctx, path);
    os.LogStr(contents);
}
