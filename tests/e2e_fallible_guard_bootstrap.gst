type MyPayload struct {
    ProtocolID: int,
    Length: int
}

func scan_directories_recursive(ctx: &Arena, dir_path: str) {
    guard d := os.OpenDir(ctx, dir_path) else {
        os.LogStr("OpenDir failed");
        return;
    }

    mut loop_active := 1;
    while loop_active == 1 {
        mut opt_entry := os.ReadDir(ctx, d);
        if opt_entry.Ok {
            mut name := opt_entry.Val.name;
            mut is_dir := opt_entry.Val.is_dir;
            if is_dir == 1 {
                if std.str_eq(name, ".") == 0 && std.str_eq(name, "..") == 0 {
                    mut nested_path := os.path_join(dir_path, name, ctx);
                    scan_directories_recursive(ctx, nested_path);
                }
            } else {
                os.LogStr(name);
            }
        } else {
            loop_active = 0;
        }
    }
    os.CloseDir(d);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    // 1. Test multiple AsCast operations on raw buffers
    mut payload := os.MockPayload();
    
    guard p1 := payload as &MyPayload else {
        os.LogStr("Cast 1 failed");
        return;
    }
    os.LogInt(p1.ProtocolID);

    guard p2 := payload as &MyPayload else {
        os.LogStr("Cast 2 failed");
        return;
    }
    os.LogInt(p2.Length);

    // 2. Perform nested directory scanning using guard
    mut test_dir := "temp_e2e_guard_test_dir";
    scan_directories_recursive(ctx, test_dir);
}