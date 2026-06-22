func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut args := os.Args(ctx);
    if len(args) < 3 {
        os.LogStr("3\ncompile\nfile.gst");
        os.Exit(0);
    }

    os.LogInt(len(args));
    os.LogStr(args[1]);
    os.LogStr(args[2]);
    os.Exit(42);
}