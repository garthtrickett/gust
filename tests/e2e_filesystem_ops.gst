func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    // 1. Write a file and read it back
    mut path := "temp_e2e_filesystem_test.txt";
    mut contents := "Hello from self-hosted Gust compiler File System E2E!";
    mut success := os.WriteFile(path, contents);
    os.LogInt(success);

    mut read_back := os.ReadFile(ctx, path);
    os.LogStr(read_back);

    // 2. Check for non-existent paths
    mut read_nonexistent := os.ReadFile(ctx, "nonexistent_file_xyz.txt");
    os.LogInt(len(read_nonexistent));

    // 3. Path joins containing relative structures (../)
    mut joined_path := os.path_join("a/b", "../../c", ctx);
    os.LogStr(joined_path);

    // 4. Read entry names inside a test directory
    mut opt_dir := os.OpenDir(ctx, "temp_e2e_filesystem_dir");
    if opt_dir.Ok {
        mut d := opt_dir.Val;
        
        mut loop_active := 1;
        while loop_active == 1 {
            mut opt_entry := os.ReadDir(ctx, d);
            if opt_entry.Ok {
                mut name := opt_entry.Val.name;
                if len(name) > 4 {
                    mut ext := std.str_slice(name, len(name) - 4, len(name));
                    if std.str_eq(ext, ".gst") {
                        os.LogStr(name);
                    } 
                }
            } else {
                loop_active = 0;
            }
        }
        os.CloseDir(d);
    }
}