import "mir_resource_authority.gst" as authority;
import "mir_failure_cleanup.gst" as failure;
import "mir_failure_cleanup_mir_to_c.gst" as failure_mir_to_c;

func fail(message: str) { os.LogStr(message); os.Exit(1); }

func add_failure_resource(table: authority.MirResourceAuthorityTable[ctx], form_id: str, ctx: &Arena) authority.MirResourceAuthorityTable[ctx] {
    mut resource_id := std.Concat("resource:failure:", form_id);
    mut type_id := std.Concat("type:failure:", form_id);
    mut destructor_id := std.Concat("destructor:failure:", form_id);
    mut scope_exit_id := std.Concat("failure-edge:", form_id);

    mut destructor: authority.MirDestructorIdentity[ctx];
    destructor.destructor_id = std.Clone(ctx, destructor_id);
    destructor.resource_type_id = std.Clone(ctx, type_id);
    destructor.runtime_symbol = std.Clone(ctx, "phase15_failure_resource_destroy");
    destructor.descriptor_id = std.Clone(ctx, std.Concat("descriptor:failure:", form_id));
    destructor.target_id = std.Clone(ctx, "x86_64-linux-gnu");
    destructor.target_triple = std.Clone(ctx, "x86_64-unknown-linux-gnu");
    table = authority.mir_resource_table_with_destructor(table, destructor, ctx);

    mut resource: authority.MirResourceIdentity[ctx];
    resource.resource_id = std.Clone(ctx, resource_id);
    resource.value_id = std.Clone(ctx, std.Concat("value:failure:", form_id));
    resource.resource_type_id = std.Clone(ctx, type_id);
    resource.source_declaration_id = std.Clone(ctx, std.Concat("decl:failure:", form_id));
    resource.source_location = std.Clone(ctx, "compiler/future/p15_selected_failure_cleanup_source.gst:2:5");
    resource.owning_function = std.Clone(ctx, "selected_runtime_failure");
    resource.owning_scope = std.Clone(ctx, "scope:selected_runtime_failure");
    resource.resource_kind = std.Clone(ctx, "selected_failure_resource");
    resource.destructor_id = std.Clone(ctx, destructor_id);
    resource.close_capability_id = std.Clone(ctx, "none");
    resource.copy_policy = std.Clone(ctx, "prohibited");
    resource.move_policy = std.Clone(ctx, "move_only");
    resource.cleanup_policy = std.Clone(ctx, "failure_or_scope_exit_exactly_once");
    resource.target_id = std.Clone(ctx, "x86_64-linux-gnu");
    resource.target_triple = std.Clone(ctx, "x86_64-unknown-linux-gnu");
    resource.layout_id = std.Clone(ctx, "layout:failure_resource");
    table = authority.mir_resource_table_with_resource(table, resource, ctx);

    mut cleanup: authority.MirCleanupObligation[ctx];
    cleanup.cleanup_id = std.Clone(ctx, std.Concat("cleanup:failure:", form_id));
    cleanup.resource_id = std.Clone(ctx, resource_id);
    cleanup.destructor_id = std.Clone(ctx, destructor_id);
    cleanup.cleanup_reason = std.Clone(ctx, "selected_failure_edge");
    cleanup.scope_exit_id = std.Clone(ctx, scope_exit_id);
    cleanup.insertion_scope = std.Clone(ctx, "scope:selected_runtime_failure");
    cleanup.execution_order = 1;
    cleanup.source_location = std.Clone(ctx, "compiler/future/p15_selected_failure_cleanup_source.gst:2:5");
    cleanup.target_block = std.Clone(ctx, std.Concat("failure_cleanup_", form_id));
    cleanup.exactly_once = 1;
    cleanup.manual_close_policy = std.Clone(ctx, "manual_close_suppresses_cleanup");
    cleanup.move_policy = std.Clone(ctx, "moved_resource_not_cleaned");
    cleanup.early_return_policy = std.Clone(ctx, "cleanup_before_return");
    cleanup.failure_policy = std.Clone(ctx, "selected_failure_cleanup");
    table = authority.mir_resource_table_with_cleanup(table, cleanup, ctx);

    mut state: authority.MirResourceState[ctx];
    state.resource_id = std.Clone(ctx, resource_id);
    state.program_point = std.Clone(ctx, std.Concat("point:failure:after_cleanup:", form_id));
    state.state = std.Clone(ctx, "destroyed");
    table = authority.mir_resource_table_with_state(table, state, ctx);
    return table;
}

func make_form(form_id: str, failure_stage: str, terminal_kind: str, stable_authority: str, exit_status: int, with_cleanup: int, ctx: &Arena) failure.MirFailureCleanupForm[ctx] {
    mut form: failure.MirFailureCleanupForm[ctx];
    form.form_id = std.Clone(ctx, form_id);
    form.failure_stage = std.Clone(ctx, failure_stage);
    form.terminal_kind = std.Clone(ctx, terminal_kind);
    form.stable_authority = std.Clone(ctx, stable_authority);
    form.exit_status = exit_status;
    form.output_preserved = 1;
    if with_cleanup == 1 {
        form.cleanup_policy = std.Clone(ctx, "cleanup_live_resources_then_terminate");
        form.resource_id = std.Clone(ctx, std.Concat("resource:failure:", form_id));
        form.scope_exit_id = std.Clone(ctx, std.Concat("failure-edge:", form_id));
        form.final_state = std.Clone(ctx, "destroyed");
        form.cleanup_count = 1;
        form.destructor_count = 1;
    } else {
        form.cleanup_policy = std.Clone(ctx, "no_cleanup_resource_not_initialized");
        form.resource_id = std.Clone(ctx, "none");
        form.scope_exit_id = std.Clone(ctx, "none");
        form.final_state = std.Clone(ctx, "uninitialized");
        form.cleanup_count = 0;
        form.destructor_count = 0;
    }
    return form;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut table := authority.mir_resource_make_empty_table("x86_64-linux-gnu", "x86_64-unknown-linux-gnu", &ctx);
    table = add_failure_resource(table, "runtime_failure_return", &ctx);
    table = add_failure_resource(table, "selected_panic", &ctx);
    table = add_failure_resource(table, "native_op_failure_edge", &ctx);

    mut plan := failure.mir_failure_cleanup_make_plan(&ctx);
    plan = failure.mir_failure_cleanup_with_form(plan, make_form("trap_before_exec", "before_driver_discovery", "compiler_rejection", "compiler_resource_cleanup_verifier", 65, 0, &ctx), &ctx);
    plan = failure.mir_failure_cleanup_with_form(plan, make_form("runtime_failure_return", "runtime_failure_status_edge", "failure_return", "canonical_mir_failure_return.v1", 82, 1, &ctx), &ctx);
    plan = failure.mir_failure_cleanup_with_form(plan, make_form("selected_panic", "compiler_selected_panic_edge", "trap_after_cleanup", "gust.compiler_panic.v1", 101, 1, &ctx), &ctx);
    plan = failure.mir_failure_cleanup_with_form(plan, make_form("native_op_failure_edge", "canonical_mir_native_failure_edge", "propagate_native_status", "gust.compiler_native_failure.v1", 74, 1, &ctx), &ctx);

    mut validation := failure.mir_failure_cleanup_validate(plan, table, &ctx);
    if validation.valid == 0 { fail(std.Concat("Phase 15.12 failure cleanup plan rejected: ", validation.reason_code)); }
    mut request := failure.mir_failure_cleanup_append_to_request("", plan, table, &ctx);
    mut witness := failure_mir_to_c.mir_failure_cleanup_mir_to_c_lower(plan, table, &ctx);
    if std.str_find(witness, "cleanup_count=3") == 0 - 1 ||
       std.str_find(witness, "exactly_once=1") == 0 - 1 ||
       std.str_find(witness, "output_preserved=1") == 0 - 1
    { fail("Phase 15.12 failure cleanup witness lost selected policy"); }
    if os.WriteFile("/tmp/gust-phase15-failure-cleanup.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase15-failure-cleanup.mir-to-c.witness", witness) == 0
    { fail("Phase 15.12 failure cleanup artifacts could not be written"); }
    os.LogStr("SUCCESS: Phase 15.12 failure cleanup parity smoke passed");
}
