import "ast.gst" as ast;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_rooted_access := typechecker.env_new(ctx);
    typechecker.env_register_struct_linear_metadata(
        &env_rooted_access, "Phase20RootGuard", 1, ctx
    );
    typechecker.env_register_struct_linear_destructor(
        &env_rooted_access,
        "Phase20RootGuard",
        "destroy_phase20_root_guard",
        ctx
    );

    mut guard_type_rooted_access := typechecker.make_type_struct(
        "Phase20RootGuard", "ctx", ctx
    );
    if typechecker.env_register_resource_parameter_obligation(
        &env_rooted_access,
        "phase20_rooted_access",
        "guard_rooted_access",
        guard_type_rooted_access,
        ctx
    ) != 1 {
        os.LogStr("Error: resource guard parameter did not receive an acquisition identity");
        os.Exit(1);
    }

    mut value_type_rooted_access := typechecker.make_type_struct(
        "Phase20ProtectedValue", "ctx", ctx
    );
    mut reference_type_rooted_access := typechecker.make_type_reference(
        value_type_rooted_access, "ctx", ctx
    );
    mut base_provenance_rooted_access :=
        typechecker.expression_provenance_safe_arena(
            reference_type_rooted_access, ctx
        );
    mut rooted_provenance_rooted_access :=
        typechecker.env_expression_provenance_rooted_in_resource_storage(
            &env_rooted_access,
            base_provenance_rooted_access,
            "guard_rooted_access",
            ctx
        );

    if typechecker.expression_provenance_has_resource_root(
        rooted_provenance_rooted_access
    ) != 1 {
        os.LogStr("Error: protected access provenance did not retain its resource root");
        os.Exit(1);
    }

    mut raw_provenance_rooted_access :=
        typechecker.expression_provenance_raw_derived(
            reference_type_rooted_access, ctx
        );
    mut rejected_raw_rooted_access :=
        typechecker.env_expression_provenance_rooted_in_resource_storage(
            &env_rooted_access,
            raw_provenance_rooted_access,
            "guard_rooted_access",
            ctx
        );
    if typechecker.expression_provenance_has_resource_root(
        rejected_raw_rooted_access
    ) != 0 {
        os.LogStr("Error: raw-derived provenance received safe guard authority");
        os.Exit(1);
    }
    if std.str_eq(
        typechecker.expression_provenance_resource_root_identity(
            rooted_provenance_rooted_access, ctx
        ),
        "parameter:phase20_rooted_access:guard_rooted_access"
    ) == 0 {
        os.LogStr("Error: protected access provenance retained the wrong resource identity");
        os.Exit(1);
    }
    if typechecker.env_expression_provenance_resource_root_is_live(
        &env_rooted_access, rooted_provenance_rooted_access, ctx
    ) != 1 {
        os.LogStr("Error: pending guard obligation was not observable as a live access root");
        os.Exit(1);
    }

    mut readback_provenance_rooted_access :=
        typechecker.expression_provenance_inherit_readback(
            rooted_provenance_rooted_access,
            reference_type_rooted_access,
            rooted_provenance_rooted_access.legacy_origins,
            ctx
        );
    if typechecker.expression_provenance_has_resource_root(
        readback_provenance_rooted_access
    ) != 1 {
        os.LogStr("Error: safe readback dropped the resource-root identity");
        os.Exit(1);
    }

    mut joined_provenance_rooted_access :=
        typechecker.expression_provenance_join(
            rooted_provenance_rooted_access,
            readback_provenance_rooted_access,
            ctx
        );
    if typechecker.expression_provenance_has_resource_root(
        joined_provenance_rooted_access
    ) != 1 {
        os.LogStr("Error: same-root provenance join dropped the resource identity");
        os.Exit(1);
    }

    mut unrooted_join_rooted_access := typechecker.expression_provenance_join(
        rooted_provenance_rooted_access,
        base_provenance_rooted_access,
        ctx
    );
    if typechecker.expression_provenance_has_resource_root(
        unrooted_join_rooted_access
    ) != 0 {
        os.LogStr("Error: conditional provenance join invented universal guard authority");
        os.Exit(1);
    }

    if typechecker.env_bind_resource_identity(
        &env_rooted_access,
        "moved_guard_rooted_access",
        "parameter:phase20_rooted_access:guard_rooted_access",
        ctx
    ) != 1 {
        os.LogStr("Error: guard move did not preserve the acquisition identity");
        os.Exit(1);
    }
    if typechecker.env_expression_provenance_resource_root_is_live(
        &env_rooted_access, rooted_provenance_rooted_access, ctx
    ) != 1 {
        os.LogStr("Error: moving the guard invalidated its shared resource identity");
        os.Exit(1);
    }

    typechecker.env_resource_obligation_set_state(
        &env_rooted_access,
        "parameter:phase20_rooted_access:guard_rooted_access",
        1,
        ctx
    );
    if typechecker.env_expression_provenance_resource_root_is_live(
        &env_rooted_access, rooted_provenance_rooted_access, ctx
    ) != 0 {
        os.LogStr("Error: terminal guard obligation remained a live access root");
        os.Exit(1);
    }

    if typechecker.expression_provenance_blocks_safe_branding(
        rooted_provenance_rooted_access
    ) != 0 || len(env_rooted_access.errors) != 0 {
        os.LogStr("Error: inert resource-root metadata changed current acceptance");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert resource-rooted access authority verified!");
}
