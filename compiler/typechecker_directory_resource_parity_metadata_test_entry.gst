import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_dir_parity := typechecker.env_new(ctx);
    env_dir_parity.current_prefix = "main__";

    if typechecker.env_struct_is_linear_resource(&env_dir_parity, "os_Dir_ctx", ctx) != 1 {
        os.LogStr("Error: directory handle parity metadata should mark os_Dir_ctx linear");
        os.Exit(1);
    }

    if typechecker.env_struct_has_linear_destructor(&env_dir_parity, "os_Dir_ctx", ctx) != 1 {
        os.LogStr("Error: directory handle parity metadata should register a destructor");
        os.Exit(1);
    }

    mut dir_destructor_parity := typechecker.env_struct_linear_destructor_name(&env_dir_parity, "os_Dir_ctx", ctx);
    if std.str_eq(dir_destructor_parity, "os.CloseDir") == 0 {
        os.LogStr("Error: directory handle parity destructor should be os.CloseDir");
        os.LogStr(dir_destructor_parity);
        os.Exit(1);
    }

    if typechecker.env_struct_has_resource_tracking_metadata(&env_dir_parity, "os_Dir_ctx", ctx) != 1 {
        os.LogStr("Error: directory handle parity metadata should make os_Dir_ctx resource-tracking eligible");
        os.Exit(1);
    }

    if typechecker.env_struct_has_resource_tracking_metadata(&env_dir_parity, "os_DirEntry_ctx", ctx) != 0 {
        os.LogStr("Error: directory entry payload should not inherit directory handle parity metadata");
        os.Exit(1);
    }

    if typechecker.env_register_open_linear_resource(&env_dir_parity, "directory_parity_resource", "os_Dir_ctx", ctx) != 1 {
        os.LogStr("Error: directory handle parity metadata should allow explicit open_linear_resources registration");
        os.Exit(1);
    }

    if typechecker.env_open_linear_resource_is_owned(&env_dir_parity, "directory_parity_resource", ctx) != 1 {
        os.LogStr("Error: explicitly registered directory parity Resource should start owned");
        os.Exit(1);
    }

    mut open_resource_destructor_parity := typechecker.env_open_linear_resource_destructor_name(&env_dir_parity, "directory_parity_resource", ctx);
    if std.str_eq(open_resource_destructor_parity, "os.CloseDir") == 0 {
        os.LogStr("Error: explicitly registered directory parity Resource should carry os.CloseDir destructor identity");
        os.LogStr(open_resource_destructor_parity);
        os.Exit(1);
    }

    if env_dir_parity.open_directories.Get("directory_parity_resource").Ok {
        os.LogStr("Error: directory Resource parity metadata must not populate legacy open_directories yet");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: directory handle Resource parity metadata verified!");
}