func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut opened := os.OpenDir(ctx, "compiler");
    if opened.Ok {
        mut directory := opened.Val;
        unsafe {
            mut raw_handle := directory.handle;
        }
        os.CloseDir(directory);
    }
    return 0;
}
