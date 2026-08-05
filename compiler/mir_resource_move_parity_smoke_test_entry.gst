import "mir_layout.gst" as layout;
import "mir_primitive_layout.gst" as primitive;
import "mir_resource_authority.gst" as authority;
import "mir_resource_value.gst" as resource_mir;
import "mir_resource_value_mir_to_c.gst" as mir_to_c;

func fail(message: str) {
    os.LogStr(message);
    os.Exit(1);
}

func make_identity(resource_id: str, value_id: str, layout_id: str, declaration_id: str, source_location: str, target_id: str, target_triple: str, ctx: &Arena) authority.MirResourceIdentity[ctx] {
    mut value: authority.MirResourceIdentity[ctx];
    value.resource_id = std.Clone(ctx, resource_id);
    value.value_id = std.Clone(ctx, value_id);
    value.resource_type_id = std.Clone(ctx, "type:gust:Phase15MoveResource");
    value.source_declaration_id = std.Clone(ctx, declaration_id);
    value.source_location = std.Clone(ctx, source_location);
    value.owning_function = std.Clone(ctx, "phase15_move_state_fixture");
    value.owning_scope = std.Clone(ctx, "scope:phase15_move_state_fixture");
    value.resource_kind = std.Clone(ctx, "native_handle_resource");
    value.destructor_id = std.Clone(ctx, "destructor:phase15:move_resource");
    value.close_capability_id = std.Clone(ctx, "close:phase15:move_resource");
    value.copy_policy = std.Clone(ctx, "non_copy_resource");
    value.move_policy = std.Clone(ctx, "canonical_move_only");
    value.cleanup_policy = std.Clone(ctx, "compiler_owned_exactly_once_cleanup");
    value.target_id = std.Clone(ctx, target_id);
    value.target_triple = std.Clone(ctx, target_triple);
    value.layout_id = std.Clone(ctx, layout_id);
    return value;
}

func make_state(resource_id: str, program_point: str, state: str, ctx: &Arena) authority.MirResourceState[ctx] {
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

func make_reference(reference_id: str, value_id: str, operation_id: str, resource_id: str, cleanup_id: str, ctx: &Arena) authority.MirResourceMirReference[ctx] {
    mut value: authority.MirResourceMirReference[ctx];
    value.reference_id = std.Clone(ctx, reference_id);
    value.mir_value_id = std.Clone(ctx, value_id);
    value.mir_operation_id = std.Clone(ctx, operation_id);
    value.resource_id = std.Clone(ctx, resource_id);
    value.cleanup_id = std.Clone(ctx, cleanup_id);
    return value;
}

func make_value(value_id: str, resource_id: str, layout_id: str, source_location: str, current_state: str, ctx: &Arena) resource_mir.MirResourceValue[ctx] {
    mut value: resource_mir.MirResourceValue[ctx];
    value.value_id = std.Clone(ctx, value_id);
    value.resource_id = std.Clone(ctx, resource_id);
    value.resource_type_id = std.Clone(ctx, "type:gust:Phase15MoveResource");
    value.layout_id = std.Clone(ctx, layout_id);
    value.owning_scope = std.Clone(ctx, "scope:phase15_move_state_fixture");
    value.source_location = std.Clone(ctx, source_location);
    value.current_state = std.Clone(ctx, current_state);
    value.destructor_id = std.Clone(ctx, "destructor:phase15:move_resource");
    value.close_capability_id = std.Clone(ctx, "close:phase15:move_resource");
    value.cleanup_policy = std.Clone(ctx, "compiler_owned_exactly_once_cleanup");
    value.copy_policy = std.Clone(ctx, "non_copy_resource");
    return value;
}

func make_carrier(carrier_id: str, resource_id: str, value_id: str, kind_tag: int, storage_id: str, backend_symbol: str, layout_id: str, source_location: str, current_state: str, ctx: &Arena) resource_mir.MirResourceCarrier[ctx] {
    mut value: resource_mir.MirResourceCarrier[ctx];
    value.carrier_id = std.Clone(ctx, carrier_id);
    value.resource_id = std.Clone(ctx, resource_id);
    value.value_id = std.Clone(ctx, value_id);
    unsafe { value.carrier_kind.tag = kind_tag; }
    value.storage_id = std.Clone(ctx, storage_id);
    value.backend_symbol = std.Clone(ctx, backend_symbol);
    value.owning_scope = std.Clone(ctx, "scope:phase15_move_state_fixture");
    value.source_location = std.Clone(ctx, source_location);
    value.resource_type_id = std.Clone(ctx, "type:gust:Phase15MoveResource");
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

    mut target_triple_move := "x86_64-unknown-linux-gnu";
    mut target_query_move := primitive.mir_primitive_layout_target(target_triple_move, ctx);
    if target_query_move.found == 0 { fail("Phase 15.3 move parity target missing"); }
    mut layout_table_move := primitive.mir_primitive_layout_table_for_target(target_triple_move, ctx);
    mut move_layout := layout.mir_layout_make_type_layout(
        "type:gust:Phase15MoveResource",
        target_query_move.target.target_id,
        "native_handle_resource",
        target_query_move.target.pointer_size,
        target_query_move.target.pointer_alignment,
        target_query_move.target.pointer_size,
        ctx
    );
    layout_table_move = layout.mir_layout_table_with_layout(layout_table_move, move_layout, ctx);

    mut resource_a_id_move := authority.mir_resource_identity_id(
        "phase15_move_state_fixture",
        "scope:phase15_move_state_fixture",
        "decl:move_source",
        0,
        ctx
    );
    mut resource_b_id_move := authority.mir_resource_identity_id(
        "phase15_move_state_fixture",
        "scope:phase15_move_state_fixture",
        "decl:reinitialized_source",
        1,
        ctx
    );
    mut cleanup_a_id_move := authority.mir_cleanup_obligation_id(
        resource_a_id_move,
        "scope_exit:phase15_move_state_fixture",
        0,
        ctx
    );
    mut authority_table_move := authority.mir_resource_make_empty_table(
        target_query_move.target.target_id,
        target_triple_move,
        ctx
    );

    mut destructor_move: authority.MirDestructorIdentity[ctx];
    destructor_move.destructor_id = std.Clone(ctx, "destructor:phase15:move_resource");
    destructor_move.resource_type_id = std.Clone(ctx, "type:gust:Phase15MoveResource");
    destructor_move.runtime_symbol = std.Clone(ctx, "gust_phase15_move_resource_destroy");
    destructor_move.descriptor_id = std.Clone(ctx, "descriptor:phase15:move_resource");
    destructor_move.target_id = std.Clone(ctx, target_query_move.target.target_id);
    destructor_move.target_triple = std.Clone(ctx, target_triple_move);
    authority_table_move = authority.mir_resource_table_with_destructor(authority_table_move, destructor_move, ctx);

    mut close_move: authority.MirCloseCapability[ctx];
    close_move.close_capability_id = std.Clone(ctx, "close:phase15:move_resource");
    close_move.resource_type_id = std.Clone(ctx, "type:gust:Phase15MoveResource");
    close_move.runtime_symbol = std.Clone(ctx, "gust_phase15_move_resource_close");
    close_move.suppresses_deferred_cleanup = 1;
    close_move.repeated_close_policy = std.Clone(ctx, "reject");
    close_move.target_id = std.Clone(ctx, target_query_move.target.target_id);
    close_move.target_triple = std.Clone(ctx, target_triple_move);
    authority_table_move = authority.mir_resource_table_with_close_capability(authority_table_move, close_move, ctx);

    authority_table_move = authority.mir_resource_table_with_resource(authority_table_move, make_identity(resource_a_id_move, "mir.value.move.a", move_layout.layout_id, "decl:move_source", "compiler/phase15_move_source.gst:4:5", target_query_move.target.target_id, target_triple_move, ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_resource(authority_table_move, make_identity(resource_b_id_move, "mir.value.move.b", move_layout.layout_id, "decl:reinitialized_source", "compiler/phase15_move_source.gst:20:5", target_query_move.target.target_id, target_triple_move, ctx), ctx);

    mut cleanup_move: authority.MirCleanupObligation[ctx];
    cleanup_move.cleanup_id = std.Clone(ctx, cleanup_a_id_move);
    cleanup_move.resource_id = std.Clone(ctx, resource_a_id_move);
    cleanup_move.destructor_id = std.Clone(ctx, "destructor:phase15:move_resource");
    cleanup_move.cleanup_reason = std.Clone(ctx, "scope_exit");
    cleanup_move.scope_exit_id = std.Clone(ctx, "scope_exit:phase15_move_state_fixture");
    cleanup_move.insertion_scope = std.Clone(ctx, "scope:phase15_move_state_fixture");
    cleanup_move.execution_order = 0;
    cleanup_move.source_location = std.Clone(ctx, "compiler/phase15_move_source.gst:4:5");
    cleanup_move.target_block = std.Clone(ctx, "cleanup_block");
    cleanup_move.exactly_once = 1;
    cleanup_move.manual_close_policy = std.Clone(ctx, "cancel_if_manually_closed");
    cleanup_move.move_policy = std.Clone(ctx, "follow_resource_identity");
    cleanup_move.early_return_policy = std.Clone(ctx, "execute_before_return");
    cleanup_move.failure_policy = std.Clone(ctx, "selected_failure_cleanup_deferred");
    authority_table_move = authority.mir_resource_table_with_cleanup(authority_table_move, cleanup_move, ctx);

    authority_table_move = authority.mir_resource_table_with_mir_reference(authority_table_move, make_reference("reference:move:a", "mir.value.move.a", "operation:move:a:local", resource_a_id_move, "", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_mir_reference(authority_table_move, make_reference("reference:move:b", "mir.value.move.b", "operation:initialize:b:fresh", resource_b_id_move, "", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_mir_reference(authority_table_move, make_reference("reference:cleanup:move:a", "mir.value.move.a", "operation:schedule:a", resource_a_id_move, cleanup_a_id_move, ctx), ctx);

    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_a_id_move, "a.declare", "uninitialized", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_a_id_move, "a.initialize", "uninitialized", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_a_id_move, "a.move.local", "live", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_a_id_move, "a.read.destination", "live", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_a_id_move, "a.move.field", "live", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_a_id_move, "a.move.field_out", "live", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_a_id_move, "a.move.branch", "live", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_a_id_move, "a.read.branch", "live", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_a_id_move, "a.move.loop", "live", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_a_id_move, "a.read.loop", "live", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_a_id_move, "a.schedule", "live", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_a_id_move, "a.destroy", "cleanup_scheduled", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_a_id_move, "a.edge.then", "live", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_a_id_move, "a.edge.else", "live", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_a_id_move, "a.edge.loop", "live", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_b_id_move, "b.initialize.fresh", "uninitialized", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_b_id_move, "b.read", "live", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_b_id_move, "b.close", "live", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_state(authority_table_move, make_state(resource_b_id_move, "b.destroy", "manually_closed", ctx), ctx);

    authority_table_move = authority.mir_resource_table_with_transition(authority_table_move, make_transition(resource_a_id_move, "initialize", "a.initialize", "uninitialized", "live", "", "compiler/phase15_move_source.gst:4:5", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_transition(authority_table_move, make_transition(resource_a_id_move, "move", "a.move.local", "live", "moved", "", "compiler/phase15_move_source.gst:8:5", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_transition(authority_table_move, make_transition(resource_a_id_move, "use", "a.read.destination", "live", "live", "", "compiler/phase15_move_source.gst:9:5", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_transition(authority_table_move, make_transition(resource_a_id_move, "move", "a.move.field", "live", "moved", "", "compiler/phase15_move_source.gst:10:5", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_transition(authority_table_move, make_transition(resource_a_id_move, "move", "a.move.field_out", "live", "moved", "", "compiler/phase15_move_source.gst:11:5", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_transition(authority_table_move, make_transition(resource_a_id_move, "move", "a.move.branch", "live", "moved", "", "compiler/phase15_move_source.gst:12:5", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_transition(authority_table_move, make_transition(resource_a_id_move, "use", "a.read.branch", "live", "live", "", "compiler/phase15_move_source.gst:12:5", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_transition(authority_table_move, make_transition(resource_a_id_move, "move", "a.move.loop", "live", "moved", "", "compiler/phase15_move_source.gst:13:5", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_transition(authority_table_move, make_transition(resource_a_id_move, "use", "a.read.loop", "live", "live", "", "compiler/phase15_move_source.gst:14:5", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_transition(authority_table_move, make_transition(resource_a_id_move, "schedule_cleanup", "a.schedule", "live", "cleanup_scheduled", cleanup_a_id_move, "compiler/phase15_move_source.gst:15:5", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_transition(authority_table_move, make_transition(resource_a_id_move, "invoke_destructor", "a.destroy", "cleanup_scheduled", "destroyed", cleanup_a_id_move, "compiler/phase15_move_source.gst:16:5", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_transition(authority_table_move, make_transition(resource_b_id_move, "initialize", "b.initialize.fresh", "uninitialized", "live", "", "compiler/phase15_move_source.gst:20:5", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_transition(authority_table_move, make_transition(resource_b_id_move, "use", "b.read", "live", "live", "", "compiler/phase15_move_source.gst:21:5", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_transition(authority_table_move, make_transition(resource_b_id_move, "manual_close", "b.close", "live", "manually_closed", "", "compiler/phase15_move_source.gst:22:5", ctx), ctx);
    authority_table_move = authority.mir_resource_table_with_transition(authority_table_move, make_transition(resource_b_id_move, "mark_destroyed", "b.destroy", "manually_closed", "destroyed", "", "compiler/phase15_move_source.gst:23:5", ctx), ctx);

    mut table_move := resource_mir.mir_resource_mir_make_empty_table(target_query_move.target.target_id, target_triple_move, ctx);
    table_move = resource_mir.mir_resource_mir_table_with_value(table_move, make_value("mir.value.move.a", resource_a_id_move, move_layout.layout_id, "compiler/phase15_move_source.gst:4:5", "destroyed", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_value(table_move, make_value("mir.value.move.b", resource_b_id_move, move_layout.layout_id, "compiler/phase15_move_source.gst:20:5", "destroyed", ctx), ctx);

    table_move = resource_mir.mir_resource_mir_table_with_carrier(table_move, make_carrier("carrier:a:source", resource_a_id_move, "mir.value.move.a", 0, "local:source", "gust_move_a_source", move_layout.layout_id, "compiler/phase15_move_source.gst:4:5", "moved", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_carrier(table_move, make_carrier("carrier:a:destination", resource_a_id_move, "mir.value.move.a", 0, "local:destination", "gust_move_a_destination", move_layout.layout_id, "compiler/phase15_move_source.gst:8:5", "moved", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_carrier(table_move, make_carrier("carrier:a:field", resource_a_id_move, "mir.value.move.a", 4, "aggregate:holder.resource", "gust_move_a_field", move_layout.layout_id, "compiler/phase15_move_source.gst:10:5", "moved", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_carrier(table_move, make_carrier("carrier:a:field_destination", resource_a_id_move, "mir.value.move.a", 0, "local:field_destination", "gust_move_a_field_destination", move_layout.layout_id, "compiler/phase15_move_source.gst:11:5", "moved", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_carrier(table_move, make_carrier("carrier:a:branch", resource_a_id_move, "mir.value.move.a", 2, "block_arg:join:0", "gust_move_a_branch", move_layout.layout_id, "compiler/phase15_move_source.gst:12:5", "moved", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_carrier(table_move, make_carrier("carrier:a:loop", resource_a_id_move, "mir.value.move.a", 3, "block_arg:loop:0", "gust_move_a_loop", move_layout.layout_id, "compiler/phase15_move_source.gst:13:5", "destroyed", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_carrier(table_move, make_carrier("carrier:b:source", resource_b_id_move, "mir.value.move.b", 0, "local:source", "gust_move_b_source", move_layout.layout_id, "compiler/phase15_move_source.gst:20:5", "destroyed", ctx), ctx);

    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:declare:a", 0, resource_a_id_move, "mir.value.move.a", "", "carrier:a:source", "a.declare", "uninitialized", "uninitialized", "", "", "", "compiler/phase15_move_source.gst:4:5", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:initialize:a", 1, resource_a_id_move, "mir.value.move.a", "", "carrier:a:source", "a.initialize", "uninitialized", "live", "", "", "", "compiler/phase15_move_source.gst:4:5", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:move:a:local", 3, resource_a_id_move, "mir.value.move.a", "carrier:a:source", "carrier:a:destination", "a.move.local", "live", "moved", "", "", "", "compiler/phase15_move_source.gst:8:5", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:read:a:destination", 2, resource_a_id_move, "mir.value.move.a", "carrier:a:destination", "", "a.read.destination", "live", "live", "", "", "", "compiler/phase15_move_source.gst:9:5", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:move:a:field", 3, resource_a_id_move, "mir.value.move.a", "carrier:a:destination", "carrier:a:field", "a.move.field", "live", "moved", "", "", "", "compiler/phase15_move_source.gst:10:5", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:move:a:field_out", 3, resource_a_id_move, "mir.value.move.a", "carrier:a:field", "carrier:a:field_destination", "a.move.field_out", "live", "moved", "", "", "", "compiler/phase15_move_source.gst:11:5", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:move:a:branch", 3, resource_a_id_move, "mir.value.move.a", "carrier:a:field_destination", "carrier:a:branch", "a.move.branch", "live", "moved", "", "", "", "compiler/phase15_move_source.gst:12:5", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:read:a:branch", 2, resource_a_id_move, "mir.value.move.a", "carrier:a:branch", "", "a.read.branch", "live", "live", "", "", "", "compiler/phase15_move_source.gst:12:5", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:move:a:loop", 3, resource_a_id_move, "mir.value.move.a", "carrier:a:branch", "carrier:a:loop", "a.move.loop", "live", "moved", "", "", "", "compiler/phase15_move_source.gst:13:5", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:read:a:loop", 2, resource_a_id_move, "mir.value.move.a", "carrier:a:loop", "", "a.read.loop", "live", "live", "", "", "", "compiler/phase15_move_source.gst:14:5", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:schedule:a", 5, resource_a_id_move, "mir.value.move.a", "carrier:a:loop", "", "a.schedule", "live", "cleanup_scheduled", cleanup_a_id_move, "destructor:phase15:move_resource", "", "compiler/phase15_move_source.gst:15:5", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:destroy:a", 6, resource_a_id_move, "mir.value.move.a", "carrier:a:loop", "", "a.destroy", "cleanup_scheduled", "destroyed", cleanup_a_id_move, "destructor:phase15:move_resource", "", "compiler/phase15_move_source.gst:16:5", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:initialize:b:fresh", 1, resource_b_id_move, "mir.value.move.b", "", "carrier:b:source", "b.initialize.fresh", "uninitialized", "live", "", "", "", "compiler/phase15_move_source.gst:20:5", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:read:b", 2, resource_b_id_move, "mir.value.move.b", "carrier:b:source", "", "b.read", "live", "live", "", "", "", "compiler/phase15_move_source.gst:21:5", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:close:b", 4, resource_b_id_move, "mir.value.move.b", "carrier:b:source", "", "b.close", "live", "manually_closed", "", "", "close:phase15:move_resource", "compiler/phase15_move_source.gst:22:5", ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_operation(table_move, make_operation("operation:destroy:b", 7, resource_b_id_move, "mir.value.move.b", "carrier:b:source", "", "b.destroy", "manually_closed", "destroyed", "", "", "close:phase15:move_resource", "compiler/phase15_move_source.gst:23:5", ctx), ctx);

    table_move = resource_mir.mir_resource_mir_table_with_flow_edge(table_move, make_edge("edge:a:then", "then", "join", resource_a_id_move, "mir.value.move.a", "a.edge.then", "live", 0, ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_flow_edge(table_move, make_edge("edge:a:else", "else", "join", resource_a_id_move, "mir.value.move.a", "a.edge.else", "live", 0, ctx), ctx);
    table_move = resource_mir.mir_resource_mir_table_with_flow_edge(table_move, make_edge("edge:a:loop", "loop_body", "loop_header", resource_a_id_move, "mir.value.move.a", "a.edge.loop", "live", 1, ctx), ctx);

    mut move_validation := resource_mir.mir_resource_mir_table_validate(table_move, authority_table_move, layout_table_move, ctx);
    if move_validation.valid == 0 {
        fail(std.Concat("Phase 15.3 move parity table rejected: ", move_validation.reason_code));
    }

    mut move_request := resource_mir.mir_serialize_resource_mir_for_request(table_move, authority_table_move, layout_table_move, ctx);
    move_request = std.Concat(move_request, authority.mir_serialize_resource_authority_table_for_request(authority_table_move, layout_table_move, ctx));
    mut move_witness := mir_to_c.mir_resource_mir_to_c_witness(table_move, authority_table_move, layout_table_move, ctx);
    if os.WriteFile("/tmp/gust-phase15-move-state.request", move_request) == 0 ||
       os.WriteFile("/tmp/gust-phase15-move-state.mir-to-c.witness", move_witness) == 0
    {
        fail("Phase 15.3 move parity artifacts could not be written");
    }

    os.LogStr("SUCCESS: Phase 15.3 move-state parity smoke passed");
}