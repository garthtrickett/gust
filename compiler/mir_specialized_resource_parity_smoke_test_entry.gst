import "mir_resource_authority.gst" as authority;
import "mir_specialized_resource.gst" as specialized;
import "mir_specialized_resource_mir_to_c.gst" as specialized_mir_to_c;

func fail(message: str) { os.LogStr(message); os.Exit(1); }

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut table := authority.mir_resource_make_empty_table("x86_64-linux-gnu", "x86_64-unknown-linux-gnu", &ctx);

    mut destructor: authority.MirDestructorIdentity[ctx];
    destructor.destructor_id = std.Clone(ctx, "destructor:os.CloseDir");
    destructor.resource_type_id = std.Clone(ctx, "os_Dir_ctx");
    destructor.runtime_symbol = std.Clone(ctx, "os_CloseDir");
    destructor.descriptor_id = std.Clone(ctx, "descriptor:os_dir");
    destructor.target_id = std.Clone(ctx, "x86_64-linux-gnu");
    destructor.target_triple = std.Clone(ctx, "x86_64-unknown-linux-gnu");
    table = authority.mir_resource_table_with_destructor(table, destructor, &ctx);

    mut close_capability: authority.MirCloseCapability[ctx];
    close_capability.close_capability_id = std.Clone(ctx, "close:os.CloseDir");
    close_capability.resource_type_id = std.Clone(ctx, "os_Dir_ctx");
    close_capability.runtime_symbol = std.Clone(ctx, "os_CloseDir");
    close_capability.suppresses_deferred_cleanup = 1;
    close_capability.repeated_close_policy = std.Clone(ctx, "reject");
    close_capability.target_id = std.Clone(ctx, "x86_64-linux-gnu");
    close_capability.target_triple = std.Clone(ctx, "x86_64-unknown-linux-gnu");
    table = authority.mir_resource_table_with_close_capability(table, close_capability, &ctx);

    mut resource: authority.MirResourceIdentity[ctx];
    resource.resource_id = std.Clone(ctx, "resource:specialized:directory");
    resource.value_id = std.Clone(ctx, "value:specialized:directory");
    resource.resource_type_id = std.Clone(ctx, "os_Dir_ctx");
    resource.source_declaration_id = std.Clone(ctx, "decl:specialized:directory");
    resource.source_location = std.Clone(ctx, "compiler/future/p15_directory_resources_source.gst:6:9");
    resource.owning_function = std.Clone(ctx, "main");
    resource.owning_scope = std.Clone(ctx, "scope:main");
    resource.resource_kind = std.Clone(ctx, "directory");
    resource.destructor_id = std.Clone(ctx, "destructor:os.CloseDir");
    resource.close_capability_id = std.Clone(ctx, "close:os.CloseDir");
    resource.copy_policy = std.Clone(ctx, "prohibited");
    resource.move_policy = std.Clone(ctx, "immovable_while_open");
    resource.cleanup_policy = std.Clone(ctx, "manual_or_scope_exit_exactly_once");
    resource.target_id = std.Clone(ctx, "x86_64-linux-gnu");
    resource.target_triple = std.Clone(ctx, "x86_64-unknown-linux-gnu");
    resource.layout_id = std.Clone(ctx, "layout:os_dir");
    table = authority.mir_resource_table_with_resource(table, resource, &ctx);

    mut state: authority.MirResourceState[ctx];
    state.resource_id = std.Clone(ctx, resource.resource_id);
    state.program_point = std.Clone(ctx, "point:directory:after_close");
    state.state = std.Clone(ctx, "manually_closed");
    table = authority.mir_resource_table_with_state(table, state, &ctx);

    mut plan := specialized.mir_specialized_resource_make_directory_plan(&ctx);
    mut instance: specialized.MirSpecializedResourceInstance[ctx];
    instance.resource_id = std.Clone(ctx, resource.resource_id);
    instance.kind_id = std.Clone(ctx, "directory");
    instance.final_state = std.Clone(ctx, "manually_closed");
    instance.operation_sequence = std.Clone(ctx, "open_read_close");
    instance.observed_entry_count = 1;
    instance.close_count = 1;
    instance.destructor_count = 0;
    instance.filesystem_effect = std.Clone(ctx, "directory_entry_observed");
    plan = specialized.mir_specialized_resource_with_instance(plan, instance, &ctx);

    mut validation := specialized.mir_specialized_resource_validate(plan, table, &ctx);
    if validation.valid == 0 { fail(std.Concat("Phase 15.11 specialized resource plan rejected: ", validation.reason_code)); }
    mut request := specialized.mir_specialized_resource_append_to_request("", plan, table, &ctx);
    mut witness := specialized_mir_to_c.mir_specialized_resource_mir_to_c_lower(plan, table, &ctx);
    if std.str_find(witness, "generic_authority=1") == 0 - 1 || std.str_find(witness, "backend_local_state_machine=0") == 0 - 1 {
        fail("Phase 15.11 witness must prove generic authority and no backend-local state machine");
    }
    if os.WriteFile("/tmp/gust-phase15-specialized-resource.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase15-specialized-resource.mir-to-c.witness", witness) == 0
    { fail("Phase 15.11 specialized resource artifacts could not be written"); }
    os.LogStr("SUCCESS: Phase 15.11 specialized resource parity smoke passed");
}
