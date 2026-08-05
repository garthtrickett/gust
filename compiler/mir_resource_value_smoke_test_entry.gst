import "mir_layout.gst" as layout;
import "mir_primitive_layout.gst" as primitive;
import "mir_resource_authority.gst" as authority;
import "mir_resource_value.gst" as resource_mir;
import "mir_resource_value_mir_to_c.gst" as mir_to_c;

func fail(message: str) {
    os.LogStr(message);
    os.Exit(1);
}

func make_resource_identity(resource_id: str, value_id: str, type_id: str, layout_id: str, declaration_id: str, source_location: str, target_id: str, target_triple: str, ctx: &Arena) authority.MirResourceIdentity[ctx] {
    mut value: authority.MirResourceIdentity[ctx];
    value.resource_id = std.Clone(ctx, resource_id);
    value.value_id = std.Clone(ctx, value_id);
    value.resource_type_id = std.Clone(ctx, type_id);
    value.source_declaration_id = std.Clone(ctx, declaration_id);
    value.source_location = std.Clone(ctx, source_location);
    value.owning_function = std.Clone(ctx, "phase15_resource_mir_fixture");
    value.owning_scope = std.Clone(ctx, "scope:phase15_resource_mir_fixture");
    value.resource_kind = std.Clone(ctx, "native_handle_resource");
    value.destructor_id = std.Clone(ctx, "destructor:phase15:selected_resource");
    value.close_capability_id = std.Clone(ctx, "close:phase15:selected_resource");
    value.copy_policy = std.Clone(ctx, "non_copy_resource");
    value.move_policy = std.Clone(ctx, "canonical_move_only");
    value.cleanup_policy = std.Clone(ctx, "compiler_owned_exactly_once_cleanup");
    value.target_id = std.Clone(ctx, target_id);
    value.target_triple = std.Clone(ctx, target_triple);
    value.layout_id = std.Clone(ctx, layout_id);
    return value;
}

func make_resource_state(resource_id: str, program_point: str, state: str, ctx: &Arena) authority.MirResourceState[ctx] {
    mut value: authority.MirResourceState[ctx];
    value.resource_id = std.Clone(ctx, resource_id);
    value.program_point = std.Clone(ctx, program_point);
    value.state = std.Clone(ctx, state);
    return value;
}

func make_transition(resource_id: str, operation: str, program_point: str, prior_state: str, resulting_state: str, cleanup_id: str, source_location: str, ctx: &Arena) authority.MirResourceTransition[ctx] {
    mut value: authority.MirResourceTransition[ctx];
    value.transition_id = authority.mir_resource_transition_id(resource_id, operation, program_point, ctx);
    value.resource_id = std.Clone(ctx, resource_id);
    value.prior_state = std.Clone(ctx, prior_state);
    value.operation = std.Clone(ctx, operation);
    value.resulting_state = std.Clone(ctx, resulting_state);
    value.program_point = std.Clone(ctx, program_point);
    value.source_location = std.Clone(ctx, source_location);
    value.control_flow_edge = std.Clone(ctx, "none");
    value.cleanup_id = std.Clone(ctx, cleanup_id);
    value.diagnostic_reason_code = std.Clone(ctx, "resource_transition_valid");
    return value;
}

func make_mir_reference(reference_id: str, value_id: str, operation_id: str, resource_id: str, cleanup_id: str, ctx: &Arena) authority.MirResourceMirReference[ctx] {
    mut value: authority.MirResourceMirReference[ctx];
    value.reference_id = std.Clone(ctx, reference_id);
    value.mir_value_id = std.Clone(ctx, value_id);
    value.mir_operation_id = std.Clone(ctx, operation_id);
    value.resource_id = std.Clone(ctx, resource_id);
    value.cleanup_id = std.Clone(ctx, cleanup_id);
    return value;
}

func make_resource_value(value_id: str, resource_id: str, type_id: str, layout_id: str, source_location: str, current_state: str, ctx: &Arena) resource_mir.MirResourceValue[ctx] {
    mut value: resource_mir.MirResourceValue[ctx];
    value.value_id = std.Clone(ctx, value_id);
    value.resource_id = std.Clone(ctx, resource_id);
    value.resource_type_id = std.Clone(ctx, type_id);
    value.layout_id = std.Clone(ctx, layout_id);
    value.owning_scope = std.Clone(ctx, "scope:phase15_resource_mir_fixture");
    value.source_location = std.Clone(ctx, source_location);
    value.current_state = std.Clone(ctx, current_state);
    value.destructor_id = std.Clone(ctx, "destructor:phase15:selected_resource");
    value.close_capability_id = std.Clone(ctx, "close:phase15:selected_resource");
    value.cleanup_policy = std.Clone(ctx, "compiler_owned_exactly_once_cleanup");
    value.copy_policy = std.Clone(ctx, "non_copy_resource");
    return value;
}

func make_carrier(carrier_id: str, resource_id: str, value_id: str, kind_tag: int, storage_id: str, backend_symbol: str, type_id: str, layout_id: str, source_location: str, current_state: str, ctx: &Arena) resource_mir.MirResourceCarrier[ctx] {
    mut value: resource_mir.MirResourceCarrier[ctx];
    value.carrier_id = std.Clone(ctx, carrier_id);
    value.resource_id = std.Clone(ctx, resource_id);
    value.value_id = std.Clone(ctx, value_id);
    unsafe { value.carrier_kind.tag = kind_tag; }
    value.storage_id = std.Clone(ctx, storage_id);
    value.backend_symbol = std.Clone(ctx, backend_symbol);
    value.owning_scope = std.Clone(ctx, "scope:phase15_resource_mir_fixture");
    value.source_location = std.Clone(ctx, source_location);
    value.resource_type_id = std.Clone(ctx, type_id);
    value.layout_id = std.Clone(ctx, layout_id);
    value.current_state = std.Clone(ctx, current_state);
    return value;
}

func make_operation(operation_id: str, kind_tag: int, resource_id: str, value_id: str, source_carrier_id: str, destination_carrier_id: str, program_point: str, prior_state: str, resulting_state: str, cleanup_id: str, destructor_id: str, close_capability_id: str, source_location: str, ctx: &Arena) resource_mir.MirResourceOperation[ctx] {
    mut value: resource_mir.MirResourceOperation[ctx];
    value.operation_id = std.Clone(ctx, operation_id);
    unsafe { value.operation_kind.tag = kind_tag; }
    value.resource_id = std.Clone(ctx, resource_id);
    value.value_id = std.Clone(ctx, value_id);
    value.source_carrier_id = std.Clone(ctx, source_carrier_id);
    value.destination_carrier_id = std.Clone(ctx, destination_carrier_id);
    value.program_point = std.Clone(ctx, program_point);
    value.prior_state = std.Clone(ctx, prior_state);
    value.resulting_state = std.Clone(ctx, resulting_state);
    value.cleanup_id = std.Clone(ctx, cleanup_id);
    value.destructor_id = std.Clone(ctx, destructor_id);
    value.close_capability_id = std.Clone(ctx, close_capability_id);
    value.source_location = std.Clone(ctx, source_location);
    return value;
}

func make_edge(edge_id: str, from_block: str, to_block: str, resource_id: str, value_id: str, program_point: str, state: str, is_loop_backedge: int, ctx: &Arena) resource_mir.MirResourceFlowEdge[ctx] {
    mut value: resource_mir.MirResourceFlowEdge[ctx];
    value.edge_id = std.Clone(ctx, edge_id);
    value.from_block = std.Clone(ctx, from_block);
    value.to_block = std.Clone(ctx, to_block);
    value.resource_id = std.Clone(ctx, resource_id);
    value.value_id = std.Clone(ctx, value_id);
    value.program_point = std.Clone(ctx, program_point);
    value.state = std.Clone(ctx, state);
    value.is_loop_backedge = is_loop_backedge;
    return value;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_triple := "x86_64-unknown-linux-gnu";
    mut target_query := primitive.mir_primitive_layout_target(target_triple, ctx);
    if target_query.found == 0 { fail("Phase 15.2 resource MIR smoke: target missing"); }
    mut layout_table := primitive.mir_primitive_layout_table_for_target(target_triple, ctx);
    mut selected_layout := layout.mir_layout_make_type_layout(
        "type:gust:Phase15SelectedResource",
        target_query.target.target_id,
        "native_handle_resource",
        target_query.target.pointer_size,
        target_query.target.pointer_alignment,
        target_query.target.pointer_size,
        ctx
    );
    layout_table = layout.mir_layout_table_with_layout(layout_table, selected_layout, ctx);

    mut resource_a_id := authority.mir_resource_identity_id(
        "phase15_resource_mir_fixture",
        "scope:phase15_resource_mir_fixture",
        "decl:cleanup_resource",
        0,
        ctx
    );
    mut resource_b_id := authority.mir_resource_identity_id(
        "phase15_resource_mir_fixture",
        "scope:phase15_resource_mir_fixture",
        "decl:close_resource",
        1,
        ctx
    );
    mut cleanup_a_id := authority.mir_cleanup_obligation_id(
        resource_a_id,
        "scope_exit:phase15_resource_mir_fixture",
        0,
        ctx
    );
    mut authority_table := authority.mir_resource_make_empty_table(
        target_query.target.target_id,
        target_triple,
        ctx
    );

    mut destructor: authority.MirDestructorIdentity[ctx];
    destructor.destructor_id = std.Clone(ctx, "destructor:phase15:selected_resource");
    destructor.resource_type_id = std.Clone(ctx, "type:gust:Phase15SelectedResource");
    destructor.runtime_symbol = std.Clone(ctx, "gust_phase15_selected_resource_destroy");
    destructor.descriptor_id = std.Clone(ctx, "descriptor:phase15:selected_resource");
    destructor.target_id = std.Clone(ctx, target_query.target.target_id);
    destructor.target_triple = std.Clone(ctx, target_triple);
    authority_table = authority.mir_resource_table_with_destructor(authority_table, destructor, ctx);

    mut close_capability: authority.MirCloseCapability[ctx];
    close_capability.close_capability_id = std.Clone(ctx, "close:phase15:selected_resource");
    close_capability.resource_type_id = std.Clone(ctx, "type:gust:Phase15SelectedResource");
    close_capability.runtime_symbol = std.Clone(ctx, "gust_phase15_selected_resource_close");
    close_capability.suppresses_deferred_cleanup = 1;
    close_capability.repeated_close_policy = std.Clone(ctx, "reject");
    close_capability.target_id = std.Clone(ctx, target_query.target.target_id);
    close_capability.target_triple = std.Clone(ctx, target_triple);
    authority_table = authority.mir_resource_table_with_close_capability(authority_table, close_capability, ctx);

    mut identity_a := make_resource_identity(
        resource_a_id,
        "mir.value.resource.cleanup",
        "type:gust:Phase15SelectedResource",
        selected_layout.layout_id,
        "decl:cleanup_resource",
        "compiler/phase15_resource_value_source.gst:10:5",
        target_query.target.target_id,
        target_triple,
        ctx
    );
    mut identity_b := make_resource_identity(
        resource_b_id,
        "mir.value.resource.close",
        "type:gust:Phase15SelectedResource",
        selected_layout.layout_id,
        "decl:close_resource",
        "compiler/phase15_resource_value_source.gst:20:5",
        target_query.target.target_id,
        target_triple,
        ctx
    );
    authority_table = authority.mir_resource_table_with_resource(authority_table, identity_a, ctx);
    authority_table = authority.mir_resource_table_with_resource(authority_table, identity_b, ctx);

    mut cleanup: authority.MirCleanupObligation[ctx];
    cleanup.cleanup_id = std.Clone(ctx, cleanup_a_id);
    cleanup.resource_id = std.Clone(ctx, resource_a_id);
    cleanup.destructor_id = std.Clone(ctx, "destructor:phase15:selected_resource");
    cleanup.cleanup_reason = std.Clone(ctx, "scope_exit");
    cleanup.scope_exit_id = std.Clone(ctx, "scope_exit:phase15_resource_mir_fixture");
    cleanup.insertion_scope = std.Clone(ctx, "scope:phase15_resource_mir_fixture");
    cleanup.execution_order = 0;
    cleanup.source_location = std.Clone(ctx, "compiler/phase15_resource_value_source.gst:10:5");
    cleanup.target_block = std.Clone(ctx, "cleanup_block");
    cleanup.exactly_once = 1;
    cleanup.manual_close_policy = std.Clone(ctx, "cancel_if_manually_closed");
    cleanup.move_policy = std.Clone(ctx, "follow_resource_identity");
    cleanup.early_return_policy = std.Clone(ctx, "execute_before_return");
    cleanup.failure_policy = std.Clone(ctx, "selected_failure_cleanup_deferred");
    authority_table = authority.mir_resource_table_with_cleanup(authority_table, cleanup, ctx);

    authority_table = authority.mir_resource_table_with_mir_reference(authority_table, make_mir_reference("reference:resource:a", "mir.value.resource.cleanup", "operation:declare:a", resource_a_id, "", ctx), ctx);
    authority_table = authority.mir_resource_table_with_mir_reference(authority_table, make_mir_reference("reference:resource:b", "mir.value.resource.close", "operation:declare:b", resource_b_id, "", ctx), ctx);
    authority_table = authority.mir_resource_table_with_mir_reference(authority_table, make_mir_reference("reference:cleanup:a", "mir.value.resource.cleanup", "operation:schedule:a", resource_a_id, cleanup_a_id, ctx), ctx);

    authority_table = authority.mir_resource_table_with_state(authority_table, make_resource_state(resource_a_id, "a.declare", "uninitialized", ctx), ctx);
    authority_table = authority.mir_resource_table_with_state(authority_table, make_resource_state(resource_a_id, "a.initialize.local", "uninitialized", ctx), ctx);
    authority_table = authority.mir_resource_table_with_state(authority_table, make_resource_state(resource_a_id, "a.read.local", "live", ctx), ctx);
    authority_table = authority.mir_resource_table_with_state(authority_table, make_resource_state(resource_a_id, "a.move.local_to_slot", "live", ctx), ctx);
    authority_table = authority.mir_resource_table_with_state(authority_table, make_resource_state(resource_a_id, "a.initialize.slot", "moved", ctx), ctx);
    authority_table = authority.mir_resource_table_with_state(authority_table, make_resource_state(resource_a_id, "a.edge.then", "live", ctx), ctx);
    authority_table = authority.mir_resource_table_with_state(authority_table, make_resource_state(resource_a_id, "a.edge.else", "live", ctx), ctx);
    authority_table = authority.mir_resource_table_with_state(authority_table, make_resource_state(resource_a_id, "a.edge.loop", "live", ctx), ctx);
    authority_table = authority.mir_resource_table_with_state(authority_table, make_resource_state(resource_a_id, "a.schedule", "live", ctx), ctx);
    authority_table = authority.mir_resource_table_with_state(authority_table, make_resource_state(resource_a_id, "a.destroy", "cleanup_scheduled", ctx), ctx);
    authority_table = authority.mir_resource_table_with_state(authority_table, make_resource_state(resource_b_id, "b.declare", "uninitialized", ctx), ctx);
    authority_table = authority.mir_resource_table_with_state(authority_table, make_resource_state(resource_b_id, "b.initialize", "uninitialized", ctx), ctx);
    authority_table = authority.mir_resource_table_with_state(authority_table, make_resource_state(resource_b_id, "b.close", "live", ctx), ctx);
    authority_table = authority.mir_resource_table_with_state(authority_table, make_resource_state(resource_b_id, "b.destroy", "manually_closed", ctx), ctx);

    authority_table = authority.mir_resource_table_with_transition(authority_table, make_transition(resource_a_id, "initialize", "a.initialize.local", "uninitialized", "live", "", "compiler/phase15_resource_value_source.gst:10:5", ctx), ctx);
    authority_table = authority.mir_resource_table_with_transition(authority_table, make_transition(resource_a_id, "use", "a.read.local", "live", "live", "", "compiler/phase15_resource_value_source.gst:11:5", ctx), ctx);
    authority_table = authority.mir_resource_table_with_transition(authority_table, make_transition(resource_a_id, "move", "a.move.local_to_slot", "live", "moved", "", "compiler/phase15_resource_value_source.gst:12:5", ctx), ctx);
    authority_table = authority.mir_resource_table_with_transition(authority_table, make_transition(resource_a_id, "initialize", "a.initialize.slot", "moved", "live", "", "compiler/phase15_resource_value_source.gst:12:5", ctx), ctx);
    authority_table = authority.mir_resource_table_with_transition(authority_table, make_transition(resource_a_id, "schedule_cleanup", "a.schedule", "live", "cleanup_scheduled", cleanup_a_id, "compiler/phase15_resource_value_source.gst:13:5", ctx), ctx);
    authority_table = authority.mir_resource_table_with_transition(authority_table, make_transition(resource_a_id, "invoke_destructor", "a.destroy", "cleanup_scheduled", "destroyed", cleanup_a_id, "compiler/phase15_resource_value_source.gst:14:5", ctx), ctx);
    authority_table = authority.mir_resource_table_with_transition(authority_table, make_transition(resource_b_id, "initialize", "b.initialize", "uninitialized", "live", "", "compiler/phase15_resource_value_source.gst:20:5", ctx), ctx);
    authority_table = authority.mir_resource_table_with_transition(authority_table, make_transition(resource_b_id, "manual_close", "b.close", "live", "manually_closed", "", "compiler/phase15_resource_value_source.gst:21:5", ctx), ctx);
    authority_table = authority.mir_resource_table_with_transition(authority_table, make_transition(resource_b_id, "mark_destroyed", "b.destroy", "manually_closed", "destroyed", "", "compiler/phase15_resource_value_source.gst:22:5", ctx), ctx);

    mut table := resource_mir.mir_resource_mir_make_empty_table(
        target_query.target.target_id,
        target_triple,
        ctx
    );
    table = resource_mir.mir_resource_mir_table_with_value(table, make_resource_value("mir.value.resource.cleanup", resource_a_id, "type:gust:Phase15SelectedResource", selected_layout.layout_id, "compiler/phase15_resource_value_source.gst:10:5", "destroyed", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_value(table, make_resource_value("mir.value.resource.close", resource_b_id, "type:gust:Phase15SelectedResource", selected_layout.layout_id, "compiler/phase15_resource_value_source.gst:20:5", "destroyed", ctx), ctx);

    table = resource_mir.mir_resource_mir_table_with_carrier(table, make_carrier("carrier:a:local", resource_a_id, "mir.value.resource.cleanup", 0, "local:cleanup_resource", "gust_resource_slot_a_local", "type:gust:Phase15SelectedResource", selected_layout.layout_id, "compiler/phase15_resource_value_source.gst:10:5", "moved", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_carrier(table, make_carrier("carrier:a:stack", resource_a_id, "mir.value.resource.cleanup", 1, "stack_slot:cleanup_resource", "gust_resource_slot_a_stack", "type:gust:Phase15SelectedResource", selected_layout.layout_id, "compiler/phase15_resource_value_source.gst:12:5", "destroyed", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_carrier(table, make_carrier("carrier:a:branch", resource_a_id, "mir.value.resource.cleanup", 2, "block_arg:join:0", "gust_resource_slot_a_branch", "type:gust:Phase15SelectedResource", selected_layout.layout_id, "compiler/phase15_resource_value_source.gst:15:5", "live", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_carrier(table, make_carrier("carrier:a:loop", resource_a_id, "mir.value.resource.cleanup", 3, "block_arg:loop:0", "gust_resource_slot_a_loop", "type:gust:Phase15SelectedResource", selected_layout.layout_id, "compiler/phase15_resource_value_source.gst:16:5", "live", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_carrier(table, make_carrier("carrier:a:field", resource_a_id, "mir.value.resource.cleanup", 4, "aggregate:wrapper.handle", "gust_resource_slot_a_field", "type:gust:Phase15SelectedResource", selected_layout.layout_id, "compiler/phase15_resource_value_source.gst:17:5", "live", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_carrier(table, make_carrier("carrier:b:local", resource_b_id, "mir.value.resource.close", 0, "local:close_resource", "gust_resource_slot_b_local", "type:gust:Phase15SelectedResource", selected_layout.layout_id, "compiler/phase15_resource_value_source.gst:20:5", "destroyed", ctx), ctx);

    table = resource_mir.mir_resource_mir_table_with_operation(table, make_operation("operation:declare:a", 0, resource_a_id, "mir.value.resource.cleanup", "", "carrier:a:local", "a.declare", "uninitialized", "uninitialized", "", "", "", "compiler/phase15_resource_value_source.gst:10:5", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_operation(table, make_operation("operation:initialize:a:local", 1, resource_a_id, "mir.value.resource.cleanup", "", "carrier:a:local", "a.initialize.local", "uninitialized", "live", "", "", "", "compiler/phase15_resource_value_source.gst:10:5", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_operation(table, make_operation("operation:read:a", 2, resource_a_id, "mir.value.resource.cleanup", "carrier:a:local", "", "a.read.local", "live", "live", "", "", "", "compiler/phase15_resource_value_source.gst:11:5", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_operation(table, make_operation("operation:move:a", 3, resource_a_id, "mir.value.resource.cleanup", "carrier:a:local", "carrier:a:stack", "a.move.local_to_slot", "live", "moved", "", "", "", "compiler/phase15_resource_value_source.gst:12:5", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_operation(table, make_operation("operation:initialize:a:stack", 1, resource_a_id, "mir.value.resource.cleanup", "", "carrier:a:stack", "a.initialize.slot", "moved", "live", "", "", "", "compiler/phase15_resource_value_source.gst:12:5", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_operation(table, make_operation("operation:schedule:a", 5, resource_a_id, "mir.value.resource.cleanup", "carrier:a:stack", "", "a.schedule", "live", "cleanup_scheduled", cleanup_a_id, "destructor:phase15:selected_resource", "", "compiler/phase15_resource_value_source.gst:13:5", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_operation(table, make_operation("operation:destroy:a", 6, resource_a_id, "mir.value.resource.cleanup", "carrier:a:stack", "", "a.destroy", "cleanup_scheduled", "destroyed", cleanup_a_id, "destructor:phase15:selected_resource", "", "compiler/phase15_resource_value_source.gst:14:5", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_operation(table, make_operation("operation:declare:b", 0, resource_b_id, "mir.value.resource.close", "", "carrier:b:local", "b.declare", "uninitialized", "uninitialized", "", "", "", "compiler/phase15_resource_value_source.gst:20:5", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_operation(table, make_operation("operation:initialize:b", 1, resource_b_id, "mir.value.resource.close", "", "carrier:b:local", "b.initialize", "uninitialized", "live", "", "", "", "compiler/phase15_resource_value_source.gst:20:5", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_operation(table, make_operation("operation:close:b", 4, resource_b_id, "mir.value.resource.close", "carrier:b:local", "", "b.close", "live", "manually_closed", "", "", "close:phase15:selected_resource", "compiler/phase15_resource_value_source.gst:21:5", ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_operation(table, make_operation("operation:mark_destroyed:b", 7, resource_b_id, "mir.value.resource.close", "carrier:b:local", "", "b.destroy", "manually_closed", "destroyed", "", "", "close:phase15:selected_resource", "compiler/phase15_resource_value_source.gst:22:5", ctx), ctx);

    table = resource_mir.mir_resource_mir_table_with_flow_edge(table, make_edge("edge:a:then", "entry", "then", resource_a_id, "mir.value.resource.cleanup", "a.edge.then", "live", 0, ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_flow_edge(table, make_edge("edge:a:else", "entry", "else", resource_a_id, "mir.value.resource.cleanup", "a.edge.else", "live", 0, ctx), ctx);
    table = resource_mir.mir_resource_mir_table_with_flow_edge(table, make_edge("edge:a:loop", "loop_body", "loop_header", resource_a_id, "mir.value.resource.cleanup", "a.edge.loop", "live", 1, ctx), ctx);

    mut validation := resource_mir.mir_resource_mir_table_validate(
        table,
        authority_table,
        layout_table,
        ctx
    );
    if validation.valid == 0 { fail(std.Concat("Phase 15.2 resource MIR smoke rejected: ", validation.reason_code)); }

    mut c_emission := mir_to_c.mir_resource_mir_to_c_source(
        table,
        authority_table,
        layout_table,
        ctx
    );
    if c_emission.success == 0 || std.str_find(c_emission.c_source, "gust_phase15_selected_resource_destroy") == 0 - 1 {
        fail("Phase 15.2 resource MIR smoke: MIR-to-C did not consume canonical operations");
    }

    mut request := resource_mir.mir_serialize_resource_mir_for_request(
        table,
        authority_table,
        layout_table,
        ctx
    );
    request = std.Concat(request, authority.mir_serialize_resource_authority_table_for_request(authority_table, layout_table, ctx));
    mut witness := mir_to_c.mir_resource_mir_to_c_witness(
        table,
        authority_table,
        layout_table,
        ctx
    );
    if os.WriteFile("/tmp/gust-phase15-resource-mir.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase15-resource-mir.mir-to-c.witness", witness) == 0
    {
        fail("Phase 15.2 resource MIR smoke: could not write parity artifacts");
    }
    os.LogStr("SUCCESS: Phase 15.2 canonical resource MIR smoke passed");
}