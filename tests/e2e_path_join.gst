func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut p1 := os.path_join("a/b", "c", ctx);
    os.LogStr(p1);

    mut p2 := os.path_join("a/b", "../c", ctx);
    os.LogStr(p2);

    mut p3 := os.path_join("a/./b", "c/../d", ctx);
    os.LogStr(p3);

    mut p4 := os.path_join("/a/b/", "/c", ctx);
    os.LogStr(p4);

    mut p5 := os.path_join("a/b", "../../c", ctx);
    os.LogStr(p5);
}