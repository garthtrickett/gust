import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_cleanup_query := typechecker.env_new(ctx);

    typechecker.env_register_struct_linear_metadata(&env_cleanup_query, "main__CleanupQueryPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_cleanup_query, "main__CleanupQueryPayload", "close_cleanup_query_payload", ctx);
    typechecker.env_register_struct_linear_metadata(&env_cleanup_query, "main__CleanupQueryNoDestructorPayload", 1, ctx);

    if typechecker.env_count_open_linear_resources_requiring_cleanup(&env_cleanup_query, ctx) != 0 {
        os.LogStr("Error: empty cleanup query environment must have no pending cleanup");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resources_have_pending_cleanup(&env_cleanup_query, ctx) != 0 {
        os.LogStr("Error: empty cleanup query environment must not report pending cleanup");
        os.Exit(1);
    }
    if len(typechecker.env_first_open_linear_resource_requiring_cleanup(&env_cleanup_query, ctx)) != 0 {
        os.LogStr("Error: empty cleanup query environment must not report first cleanup resource");
        os.Exit(1);
    }

    typechecker.env_register_open_linear_resource(&env_cleanup_query, "owned_cleanup_query_resource", "main__CleanupQueryPayload", ctx);
    if typechecker.env_count_open_linear_resources_requiring_cleanup(&env_cleanup_query, ctx) != 1 {
        os.LogStr("Error: owned cleanup query resource must require cleanup");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resources_have_pending_cleanup(&env_cleanup_query, ctx) != 1 {
        os.LogStr("Error: owned cleanup query resource must report pending cleanup");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_first_open_linear_resource_requiring_cleanup(&env_cleanup_query, ctx), "owned_cleanup_query_resource") == 0 {
        os.LogStr("Error: first cleanup query resource did not identify owned resource");
        os.Exit(1);
    }

    typechecker.env_register_open_linear_resource(&env_cleanup_query, "moved_cleanup_query_resource", "main__CleanupQueryPayload", ctx);
    typechecker.env_try_move_open_linear_resource(&env_cleanup_query, "moved_cleanup_query_resource", ctx);
    if typechecker.env_count_open_linear_resources_requiring_cleanup(&env_cleanup_query, ctx) != 1 {
        os.LogStr("Error: moved cleanup query resource must not add pending cleanup");
        os.Exit(1);
    }

    typechecker.env_register_open_linear_resource(&env_cleanup_query, "closed_cleanup_query_resource", "main__CleanupQueryPayload", ctx);
    typechecker.env_try_close_open_linear_resource(&env_cleanup_query, "closed_cleanup_query_resource", ctx);
    if typechecker.env_count_open_linear_resources_requiring_cleanup(&env_cleanup_query, ctx) != 1 {
        os.LogStr("Error: closed cleanup query resource must not add pending cleanup");
        os.Exit(1);
    }

    typechecker.env_register_open_linear_resource(&env_cleanup_query, "borrowed_cleanup_query_resource", "main__CleanupQueryPayload", ctx);
    typechecker.env_try_borrow_open_linear_resource(&env_cleanup_query, "borrowed_cleanup_query_resource", ctx);
    if typechecker.env_count_open_linear_resources_requiring_cleanup(&env_cleanup_query, ctx) != 1 {
        os.LogStr("Error: borrowed cleanup query resource must not add owner cleanup");
        os.Exit(1);
    }

    typechecker.env_register_open_linear_resource(&env_cleanup_query, "scheduled_cleanup_query_resource", "main__CleanupQueryPayload", ctx);
    typechecker.env_try_schedule_open_linear_resource_destructor(&env_cleanup_query, "scheduled_cleanup_query_resource", ctx);
    if typechecker.env_count_open_linear_resources_requiring_cleanup(&env_cleanup_query, ctx) != 1 {
        os.LogStr("Error: destructor-scheduled cleanup query resource must not add pending cleanup");
        os.Exit(1);
    }

    typechecker.env_register_open_linear_resource(&env_cleanup_query, "no_destructor_cleanup_query_resource", "main__CleanupQueryNoDestructorPayload", ctx);
    if typechecker.env_count_open_linear_resources_requiring_cleanup(&env_cleanup_query, ctx) != 2 {
        os.LogStr("Error: owned resource without destructor identity must still be counted as pending cleanup");
        os.Exit(1);
    }

    typechecker.env_try_close_open_linear_resource(&env_cleanup_query, "owned_cleanup_query_resource", ctx);
    if typechecker.env_count_open_linear_resources_requiring_cleanup(&env_cleanup_query, ctx) != 1 {
        os.LogStr("Error: closing owned cleanup query resource should leave one pending cleanup");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_first_open_linear_resource_requiring_cleanup(&env_cleanup_query, ctx), "no_destructor_cleanup_query_resource") == 0 {
        os.LogStr("Error: first cleanup query resource did not advance to no-destructor resource");
        os.Exit(1);
    }

    typechecker.env_try_close_open_linear_resource(&env_cleanup_query, "no_destructor_cleanup_query_resource", ctx);
    if typechecker.env_count_open_linear_resources_requiring_cleanup(&env_cleanup_query, ctx) != 0 {
        os.LogStr("Error: closing all owned cleanup query resources should clear pending cleanup");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resources_have_pending_cleanup(&env_cleanup_query, ctx) != 0 {
        os.LogStr("Error: cleanup query helper must report no pending cleanup after all terminal transitions");
        os.Exit(1);
    }
    if len(typechecker.env_first_open_linear_resource_requiring_cleanup(&env_cleanup_query, ctx)) != 0 {
        os.LogStr("Error: cleanup query helper must not report first cleanup resource after all terminal transitions");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert linear resource cleanup query helpers verified!");
}