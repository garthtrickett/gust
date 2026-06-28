import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_scope_state_original := typechecker.env_new(ctx);
    typechecker.env_register_struct_linear_metadata(&env_scope_state_original, "main__ScopeStateResource", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_scope_state_original, "main__ScopeStateResource", "close_scope_state_resource", ctx);

    typechecker.env_register_open_linear_resource(&env_scope_state_original, "scope_state_resource", "main__ScopeStateResource", ctx);
    if typechecker.env_open_linear_resource_is_owned(&env_scope_state_original, "scope_state_resource", ctx) != 1 {
        os.LogStr("Error: original scope-state resource must start owned before clone");
        os.Exit(1);
    }

    mut cloned_scope_state_map := typechecker.typechecker_clone_linear_resource_map(env_scope_state_original.open_linear_resources, ctx);
    mut env_scope_state_clone := typechecker.env_new(ctx);
    env_scope_state_clone.open_linear_resources = cloned_scope_state_map;

    if typechecker.env_open_linear_resource_is_owned(&env_scope_state_clone, "scope_state_resource", ctx) != 1 {
        os.LogStr("Error: cloned open_linear_resources map did not preserve owned state");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_open_linear_resource_destructor_name(&env_scope_state_clone, "scope_state_resource", ctx), "close_scope_state_resource") == 0 {
        os.LogStr("Error: cloned open_linear_resources map did not preserve destructor identity");
        os.Exit(1);
    }

    typechecker.env_mark_open_linear_resource_moved(&env_scope_state_original, "scope_state_resource", ctx);
    if typechecker.env_open_linear_resource_is_moved(&env_scope_state_original, "scope_state_resource", ctx) != 1 {
        os.LogStr("Error: original scope-state resource did not move after clone");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_scope_state_clone, "scope_state_resource", ctx) != 1 {
        os.LogStr("Error: cloned scope-state resource was mutated when original moved");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_moved(&env_scope_state_clone, "scope_state_resource", ctx) != 0 {
        os.LogStr("Error: cloned scope-state resource must not inherit post-clone moved state");
        os.Exit(1);
    }

    typechecker.env_mark_open_linear_resource_closed(&env_scope_state_clone, "scope_state_resource", ctx);
    if typechecker.env_open_linear_resource_is_closed(&env_scope_state_clone, "scope_state_resource", ctx) != 1 {
        os.LogStr("Error: cloned scope-state resource did not close independently");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_moved(&env_scope_state_original, "scope_state_resource", ctx) != 1 {
        os.LogStr("Error: original moved state was lost when clone closed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_closed(&env_scope_state_original, "scope_state_resource", ctx) != 0 {
        os.LogStr("Error: original scope-state resource must not inherit post-clone closed state");
        os.Exit(1);
    }

    mut empty_scope_state_map := typechecker.typechecker_clone_linear_resource_map(env_scope_state_clone.open_linear_resources, ctx);
    mut env_scope_state_restored_empty := typechecker.env_new(ctx);
    env_scope_state_restored_empty.open_linear_resources = std.HashMapNew(ctx);
    if typechecker.env_open_linear_resource_is_tracked(&env_scope_state_restored_empty, "scope_state_resource", ctx) != 0 {
        os.LogStr("Error: empty restored scope-state map must not track cloned resource");
        os.Exit(1);
    }
    env_scope_state_restored_empty.open_linear_resources = empty_scope_state_map;
    if typechecker.env_open_linear_resource_is_closed(&env_scope_state_restored_empty, "scope_state_resource", ctx) != 1 {
        os.LogStr("Error: restored cloned map did not preserve closed state");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert linear resource scope-state snapshots verified!");
}