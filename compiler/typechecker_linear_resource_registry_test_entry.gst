import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_registry_meta := typechecker.env_new(ctx);

    typechecker.env_register_struct_linear_metadata(&env_registry_meta, "main__LinearRegistryResource", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_registry_meta, "main__LinearRegistryResource", "close_linear_registry_resource", ctx);

    typechecker.env_register_struct_linear_metadata(&env_registry_meta, "main__PlainRegistryResource", 0, ctx);

    mut plain_registered_registry_meta := typechecker.env_register_open_linear_resource(&env_registry_meta, "plain_registry_resource", "main__PlainRegistryResource", ctx);
    if plain_registered_registry_meta != 0 {
        os.LogStr("Error: unannotated resource must not enter open_linear_resources registry");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_tracked(&env_registry_meta, "plain_registry_resource", ctx) != 0 {
        os.LogStr("Error: unannotated resource was tracked in open_linear_resources registry");
        os.Exit(1);
    }

    mut linear_registered_registry_meta := typechecker.env_register_open_linear_resource(&env_registry_meta, "linear_registry_resource", "main__LinearRegistryResource", ctx);
    if linear_registered_registry_meta != 1 {
        os.LogStr("Error: linear resource metadata did not enter open_linear_resources registry");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_tracked(&env_registry_meta, "linear_registry_resource", ctx) != 1 {
        os.LogStr("Error: linear resource registry tracking predicate failed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_open(&env_registry_meta, "linear_registry_resource", ctx) != 1 {
        os.LogStr("Error: newly registered linear resource must start open");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_closed(&env_registry_meta, "linear_registry_resource", ctx) != 0 {
        os.LogStr("Error: newly registered linear resource must not start closed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_moved(&env_registry_meta, "linear_registry_resource", ctx) != 0 {
        os.LogStr("Error: newly registered linear resource must not start moved");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_open_linear_resource_destructor_name(&env_registry_meta, "linear_registry_resource", ctx), "close_linear_registry_resource") == 0 {
        os.LogStr("Error: open linear resource registry did not preserve destructor identity");
        os.Exit(1);
    }

    if typechecker.env_mark_open_linear_resource_closed(&env_registry_meta, "linear_registry_resource", ctx) != 1 {
        os.LogStr("Error: closing tracked linear resource failed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_open(&env_registry_meta, "linear_registry_resource", ctx) != 0 {
        os.LogStr("Error: closed linear resource must no longer be open");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_closed(&env_registry_meta, "linear_registry_resource", ctx) != 1 {
        os.LogStr("Error: closed linear resource state was not recorded");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_moved(&env_registry_meta, "linear_registry_resource", ctx) != 0 {
        os.LogStr("Error: closed linear resource must not also be marked moved");
        os.Exit(1);
    }

    mut moved_registered_registry_meta := typechecker.env_register_open_linear_resource(&env_registry_meta, "moved_registry_resource", "main__LinearRegistryResource", ctx);
    if moved_registered_registry_meta != 1 {
        os.LogStr("Error: second linear resource metadata did not enter open_linear_resources registry");
        os.Exit(1);
    }
    if typechecker.env_mark_open_linear_resource_moved(&env_registry_meta, "moved_registry_resource", ctx) != 1 {
        os.LogStr("Error: moving tracked linear resource failed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_open(&env_registry_meta, "moved_registry_resource", ctx) != 0 {
        os.LogStr("Error: moved linear resource must no longer be open");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_moved(&env_registry_meta, "moved_registry_resource", ctx) != 1 {
        os.LogStr("Error: moved linear resource state was not recorded");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_closed(&env_registry_meta, "moved_registry_resource", ctx) != 0 {
        os.LogStr("Error: moved linear resource must not also be marked closed");
        os.Exit(1);
    }

    if typechecker.env_mark_open_linear_resource_closed(&env_registry_meta, "missing_registry_resource", ctx) != 0 {
        os.LogStr("Error: closing missing linear resource must be a no-op failure");
        os.Exit(1);
    }
    if typechecker.env_mark_open_linear_resource_moved(&env_registry_meta, "missing_registry_resource", ctx) != 0 {
        os.LogStr("Error: moving missing linear resource must be a no-op failure");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_open_linear_resource_destructor_name(&env_registry_meta, "missing_registry_resource", ctx), "") == 0 {
        os.LogStr("Error: missing open linear resource destructor lookup must default to empty string");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert open linear resource registry verified!");
}