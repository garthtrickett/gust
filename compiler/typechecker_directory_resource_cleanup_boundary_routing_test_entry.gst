import "token.gst" as token;
import "typechecker.gst" as typechecker;

func env_has_error_containing(env: *typechecker.TypeEnvironment[ctx], needle: str, ctx: &Arena) int {
    unsafe {
        mut i := 0;
        while i < len((*env).errors) {
            mut msg := (*env).errors[i].message;
            if std.str_find(msg, needle) != 0 - 1 {
                return 1;
            }
            i = i + 1;
        }
        return 0;
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span_dir_cleanup_route: token.Span;

    mut env_helper_route := typechecker.env_new(ctx);
    env_helper_route.current_prefix = "main__";
    if typechecker.env_shadow_track_open_directory_resource(&env_helper_route, "helper_route_dir", "os_Dir_ctx", ctx) != 1 {
        os.LogStr("Error: directory cleanup routing fixture should open a shadow-tracked directory Resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_requires_cleanup(&env_helper_route, "helper_route_dir", ctx) != 1 {
        os.LogStr("Error: directory shadow should reuse Resource cleanup-required transition predicate");
        os.Exit(1);
    }
    if typechecker.env_open_directory_resource_requires_cleanup(&env_helper_route, "helper_route_dir", ctx) != 1 {
        os.LogStr("Error: directory cleanup routing helper should see pending canonical cleanup");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resources_have_pending_cleanup(&env_helper_route, ctx) != 0 {
        os.LogStr("Error: historical generic diagnostic boundary should skip directory shadow records");
        os.Exit(1);
    }
    typechecker.env_validate_linear_resource_scope_exit_cleanup(&env_helper_route, span_dir_cleanup_route, ctx);
    if env_has_error_containing(&env_helper_route, "LinearResourceMissingCleanup", ctx) == 1 {
        os.LogStr("Error: historical os.CloseDir diagnostic boundary should not emit generic cleanup for directory shadows");
        os.Exit(1);
    }
    if typechecker.env_shadow_track_closed_directory_resource(&env_helper_route, "helper_route_dir", ctx) != 1 {
        os.LogStr("Error: directory cleanup routing fixture should close the canonical Resource shadow");
        os.Exit(1);
    }
    if typechecker.env_open_directory_resource_requires_cleanup(&env_helper_route, "helper_route_dir", ctx) != 0 {
        os.LogStr("Error: closed directory Resource shadow should not require cleanup");
        os.Exit(1);
    }

    mut env_compatibility_only := typechecker.env_new(ctx);
    env_compatibility_only.current_prefix = "main__";
    env_compatibility_only.open_directories.Insert("compatibility_only_dir", 1);
    if typechecker.env_open_directory_resource_requires_cleanup(&env_compatibility_only, "compatibility_only_dir", ctx) != 0 {
        os.LogStr("Error: write-only compatibility storage entered the cleanup boundary");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_directory_shadow(&env_compatibility_only, "compatibility_only_dir", ctx) != 0 {
        os.LogStr("Error: cleanup boundary synthesized canonical state from compatibility storage");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: directory cleanup boundaries read canonical Resource state only!");
}
