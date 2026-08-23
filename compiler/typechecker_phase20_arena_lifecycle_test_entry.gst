import "typechecker.gst" as typechecker;

func require_equal(actual: int, expected: int, label: str) {
    if actual != expected {
        os.LogStr(std.Concat("Error: arena lifecycle observation drifted for ", label));
        os.Exit(1);
    }
}

func require_string(actual: str, expected: str, label: str) {
    if std.str_eq(actual, expected) == 0 {
        os.LogStr(std.Concat("Error: arena lifecycle identity drifted for ", label));
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut env := typechecker.env_new(ctx);

    env.current_function_identity_scope = "main";
    mut alpha_identity := typechecker.arena_lifecycle_identity_for_binding(&env, "alpha", ctx);
    mut beta_identity := typechecker.arena_lifecycle_identity_for_binding(&env, "beta", ctx);
    typechecker.env_arena_lifecycle_record_binding(&env, "alpha", std.Clone(ctx, alpha_identity), ctx);
    typechecker.env_arena_lifecycle_record_binding(&env, "alias", std.Clone(ctx, alpha_identity), ctx);
    typechecker.env_arena_lifecycle_record_binding(&env, "holder.arena", std.Clone(ctx, alpha_identity), ctx);
    typechecker.env_arena_lifecycle_record_binding(&env, "beta", std.Clone(ctx, beta_identity), ctx);

    require_string(
        typechecker.env_arena_lifecycle_lookup_binding(&env, "alias", ctx),
        std.Clone(ctx, alpha_identity),
        "local alias"
    );
    require_string(
        typechecker.env_arena_lifecycle_lookup_binding(&env, "holder.arena", ctx),
        std.Clone(ctx, alpha_identity),
        "field alias"
    );
    if std.str_eq(std.Clone(ctx, alpha_identity), std.Clone(ctx, beta_identity)) == 1 {
        os.LogStr("Error: two distinct arenas collapsed to one lifecycle identity");
        os.Exit(1);
    }

    mut branded := typechecker.make_type_index("Any", "alpha", ctx);
    mut substituted_identity := typechecker.env_arena_lifecycle_identity_from_type(
        &env, branded, "", ctx
    );
    require_string(substituted_identity, std.Clone(ctx, alpha_identity), "generic brand substitution");

    typechecker.env_arena_lifecycle_observe_identity(&env, std.Clone(ctx, alpha_identity), "allocation", ctx);
    typechecker.env_arena_lifecycle_observe_identity(&env, std.Clone(ctx, alpha_identity), "clone_destination", ctx);
    typechecker.env_arena_lifecycle_observe_identity(&env, std.Clone(ctx, alpha_identity), "write", ctx);
    typechecker.env_arena_lifecycle_observe_identity(&env, std.Clone(ctx, alpha_identity), "free", ctx);
    mut alpha_state := typechecker.env_arena_lifecycle_get_state(&env, std.Clone(ctx, alpha_identity), ctx);
    require_equal(alpha_state.allocation_observations, 1, "allocation");
    require_equal(alpha_state.clone_destination_observations, 1, "clone destination");
    require_equal(alpha_state.write_observations, 1, "write");
    require_equal(alpha_state.free_observations, 1, "free");
    require_equal(alpha_state.state, typechecker.arena_lifecycle_state_live(), "inert Free");
    if typechecker.arena_lifecycle_state_freed() == typechecker.arena_lifecycle_state_live() {
        os.LogStr("Error: live and freed lifecycle states collapsed");
        os.Exit(1);
    }

    mut beta_state := typechecker.env_arena_lifecycle_get_state(&env, std.Clone(ctx, beta_identity), ctx);
    require_equal(beta_state.allocation_observations, 0, "independent arena allocation");
    require_equal(beta_state.free_observations, 0, "independent arena Free");

    env.current_function_identity_scope = "helper";
    mut helper_identity := typechecker.arena_lifecycle_identity_for_binding(&env, "alpha", ctx);
    typechecker.env_arena_lifecycle_record_binding(&env, "alpha", std.Clone(ctx, helper_identity), ctx);
    if std.str_eq(helper_identity, "main::alpha") == 1 {
        os.LogStr("Error: same parameter spelling collapsed across function scopes");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: Phase 20 arena lifecycle observation authority verified");
}
