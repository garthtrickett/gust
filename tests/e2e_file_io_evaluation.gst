func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut path := "test_e2e_file_io_evaluation_output.txt";
    mut contents := "Hello from Gust Compiler File I/O!";
    
    mut success := os.WriteFile(path, contents);
    os.LogInt(success);

    mut read_back := os.ReadFile(ctx, path);
    os.LogStr(read_back);
    os.LogInt(len(read_back));
}
