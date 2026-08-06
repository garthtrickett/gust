import "mir_layout.gst" as layout;
import "mir_primitive_layout.gst" as primitive;
import "mir_resource_authority.gst" as authority;
import "mir_resource_value.gst" as resource_mir;
import "mir_resource_value_mir_to_c.gst" as mir_to_c;
import "mir_resource_reassignment.gst" as reassignment;
import "mir_resource_reassignment_mir_to_c.gst" as reassignment_mir_to_c;

func fail(message: str) {
    os.LogStr(message);
    os.Exit(1);
}

func make_identity(resource_id: str, value_id: str, layout_id: str, declaration_id: str, source_location: str, target_id: str, target_triple: str, ctx: &Arena) authority.MirResourceIdentity[ctx] {
    mut value: authority.MirResourceIdentity[ctx];
    value.resource_id = std.Clone(ctx, resource_id);
    value.value_id = std.Clone(ctx, value_id);
    value.resource_type_id = std.Clone(ctx, "type:gust:Phase15ReassignmentResource");
    value.source_declaration_id = std.Clone(ctx, declaration_id);
    value.source_location = std.Clone(ctx, source_location);
    value.owning_function = std.Clone(ctx, "phase15_resource_reassignment_fixture");
    value.owning_scope = std.Clone(ctx, "scope:phase15_resource_reassignment_fixture");
    value.resource_kind = std.Clone(ctx, "native_handle_resource");
    value.destructor_id = std.Clone(ctx, "destructor:phase15:reassignment_resource");
    value.close_capability_id = std.Clone(ctx, "close:phase15:reassignment_resource");
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
    value.resource_type_id = std.Clone(ctx, "type:gust:Phase15ReassignmentResource");
    value.layout_id = std.Clone(ctx, layout_id);
    value.owning_scope = std.Clone(ctx, "scope:phase15_resource_reassignment_fixture");
    value.source_location = std.Clone(ctx, source_location);
    value.current_state = std.Clone(ctx, current_state);
    value.destructor_id = std.Clone(ctx, "destructor:phase15:reassignment_resource");
    value.close_capability_id = std.Clone(ctx, "close:phase15:reassignment_resource");
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
    value.owning_scope = std.Clone(ctx, "scope:phase15_resource_reassignment_fixture");
    value.source_location = std.Clone(ctx, source_location);
    value.resource_type_id = std.Clone(ctx, "type:gust:Phase15ReassignmentResource");
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

func make_flow_edge(edge_id: str, from_block: str, to_block: str, resource_id: str, value_id: str, program_point: str, is_loop_backedge: int, ctx: &Arena) resource_mir.MirResourceFlowEdge[ctx] {
    mut edge: resource_mir.MirResourceFlowEdge[ctx];
    edge.edge_id = std.Clone(ctx, edge_id);
    edge.from_block = std.Clone(ctx, from_block);
    edge.to_block = std.Clone(ctx, to_block);
    edge.resource_id = std.Clone(ctx, resource_id);
    edge.value_id = std.Clone(ctx, value_id);
    edge.program_point = std.Clone(ctx, program_point);
    edge.state = std.Clone(ctx, "live");
    edge.is_loop_backedge = is_loop_backedge;
    return edge;
}

func make_cleanup(cleanup_id: str, resource_id: str, order: int, source_location: str, ctx: &Arena) authority.MirCleanupObligation[ctx] {
    mut cleanup: authority.MirCleanupObligation[ctx];
    cleanup.cleanup_id = std.Clone(ctx, cleanup_id);
    cleanup.resource_id = std.Clone(ctx, resource_id);
    cleanup.destructor_id = std.Clone(ctx, "destructor:phase15:reassignment_resource");
    cleanup.cleanup_reason = std.Clone(ctx, "replacement_point");
    cleanup.scope_exit_id = std.Clone(ctx, "scope_exit:phase15_resource_reassignment_fixture");
    cleanup.insertion_scope = std.Clone(ctx, "scope:phase15_resource_reassignment_fixture");
    cleanup.execution_order = order;
    cleanup.source_location = std.Clone(ctx, source_location);
    cleanup.target_block = std.Clone(ctx, "replacement_cleanup_block");
    cleanup.exactly_once = 1;
    cleanup.manual_close_policy = std.Clone(ctx, "cancel_if_manually_closed");
    cleanup.move_policy = std.Clone(ctx, "follow_resource_identity");
    cleanup.early_return_policy = std.Clone(ctx, "execute_before_return");
    cleanup.failure_policy = std.Clone(ctx, "selected_failure_cleanup_deferred");
    return cleanup;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_triple_reassign := "x86_64-unknown-linux-gnu";
    mut target_query_reassign := primitive.mir_primitive_layout_target(target_triple_reassign, ctx);
    if target_query_reassign.found == 0 { fail("Phase 15.4 reassignment target missing"); }
    mut layout_table_reassign := primitive.mir_primitive_layout_table_for_target(target_triple_reassign, ctx);
    mut resource_layout_reassign := layout.mir_layout_make_type_layout(
        "type:gust:Phase15ReassignmentResource",
        target_query_reassign.target.target_id,
        "native_handle_resource",
        target_query_reassign.target.pointer_size,
        target_query_reassign.target.pointer_alignment,
        target_query_reassign.target.pointer_size,
        ctx
    );
    layout_table_reassign = layout.mir_layout_table_with_layout(layout_table_reassign, resource_layout_reassign, ctx);

    mut predecessor_id_reassign := authority.mir_resource_identity_id(
        "phase15_resource_reassignment_fixture",
        "scope:phase15_resource_reassignment_fixture",
        "decl:predecessor",
        0,
        ctx
    );
    mut old_id_reassign := authority.mir_resource_identity_id(
        "phase15_resource_reassignment_fixture",
        "scope:phase15_resource_reassignment_fixture",
        "decl:old",
        1,
        ctx
    );
    mut replacement_id_reassign := authority.mir_resource_identity_id(
        "phase15_resource_reassignment_fixture",
        "scope:phase15_resource_reassignment_fixture",
        "decl:replacement",
        2,
        ctx
    );
    mut predecessor_cleanup_id_reassign := authority.mir_cleanup_obligation_id(
        predecessor_id_reassign,
        "scope_exit:phase15_resource_reassignment_fixture",
        0,
        ctx
    );
    mut old_cleanup_id_reassign := authority.mir_cleanup_obligation_id(
        old_id_reassign,
        "scope_exit:phase15_resource_reassignment_fixture",
        1,
        ctx
    );

    mut authority_table_reassign := authority.mir_resource_make_empty_table(
        target_query_reassign.target.target_id,
        target_triple_reassign,
        ctx
    );
    mut destructor_reassign: authority.MirDestructorIdentity[ctx];
    destructor_reassign.destructor_id = std.Clone(ctx, "destructor:phase15:reassignment_resource");
    destructor_reassign.resource_type_id = std.Clone(ctx, "type:gust:Phase15ReassignmentResource");
    destructor_reassign.runtime_symbol = std.Clone(ctx, "gust_phase15_reassignment_resource_destroy");
    destructor_reassign.descriptor_id = std.Clone(ctx, "descriptor:phase15:reassignment_resource");
    destructor_reassign.target_id = std.Clone(ctx, target_query_reassign.target.target_id);
    destructor_reassign.target_triple = std.Clone(ctx, target_triple_reassign);
    authority_table_reassign = authority.mir_resource_table_with_destructor(authority_table_reassign, destructor_reassign, ctx);

    mut close_reassign: authority.MirCloseCapability[ctx];
    close_reassign.close_capability_id = std.Clone(ctx, "close:phase15:reassignment_resource");
    close_reassign.resource_type_id = std.Clone(ctx, "type:gust:Phase15ReassignmentResource");
    close_reassign.runtime_symbol = std.Clone(ctx, "gust_phase15_reassignment_resource_close");
    close_reassign.suppresses_deferred_cleanup = 1;
    close_reassign.repeated_close_policy = std.Clone(ctx, "reject");
    close_reassign.target_id = std.Clone(ctx, target_query_reassign.target.target_id);
    close_reassign.target_triple = std.Clone(ctx, target_triple_reassign);
    authority_table_reassign = authority.mir_resource_table_with_close_capability(authority_table_reassign, close_reassign, ctx);

    authority_table_reassign = authority.mir_resource_table_with_resource(authority_table_reassign, make_identity(predecessor_id_reassign, "mir.value.reassignment.predecessor", resource_layout_reassign.layout_id, "decl:predecessor", "compiler/phase15_reassignment_source.gst:4:5", target_query_reassign.target.target_id, target_triple_reassign, ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_resource(authority_table_reassign, make_identity(old_id_reassign, "mir.value.reassignment.old", resource_layout_reassign.layout_id, "decl:old", "compiler/phase15_reassignment_source.gst:10:5", target_query_reassign.target.target_id, target_triple_reassign, ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_resource(authority_table_reassign, make_identity(replacement_id_reassign, "mir.value.reassignment.replacement", resource_layout_reassign.layout_id, "decl:replacement", "compiler/phase15_reassignment_source.gst:20:5", target_query_reassign.target.target_id, target_triple_reassign, ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_cleanup(authority_table_reassign, make_cleanup(predecessor_cleanup_id_reassign, predecessor_id_reassign, 0, "compiler/phase15_reassignment_source.gst:4:5", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_cleanup(authority_table_reassign, make_cleanup(old_cleanup_id_reassign, old_id_reassign, 1, "compiler/phase15_reassignment_source.gst:10:5", ctx), ctx);

    authority_table_reassign = authority.mir_resource_table_with_mir_reference(authority_table_reassign, make_reference("reference:reassignment:predecessor", "mir.value.reassignment.predecessor", "operation:reassignment:predecessor:move", predecessor_id_reassign, "", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_mir_reference(authority_table_reassign, make_reference("reference:reassignment:old", "mir.value.reassignment.old", "operation:reassignment:old:destroy", old_id_reassign, "", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_mir_reference(authority_table_reassign, make_reference("reference:reassignment:replacement", "mir.value.reassignment.replacement", "operation:reassignment:replacement:initialize", replacement_id_reassign, "", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_mir_reference(authority_table_reassign, make_reference("reference:reassignment:cleanup:predecessor", "mir.value.reassignment.predecessor", "operation:reassignment:predecessor:schedule", predecessor_id_reassign, predecessor_cleanup_id_reassign, ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_mir_reference(authority_table_reassign, make_reference("reference:reassignment:cleanup:old", "mir.value.reassignment.old", "operation:reassignment:old:schedule", old_id_reassign, old_cleanup_id_reassign, ctx), ctx);

    authority_table_reassign = authority.mir_resource_table_with_state(authority_table_reassign, make_state(predecessor_id_reassign, "predecessor.declare", "uninitialized", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_state(authority_table_reassign, make_state(predecessor_id_reassign, "predecessor.initialize", "uninitialized", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_state(authority_table_reassign, make_state(predecessor_id_reassign, "predecessor.move", "live", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_state(authority_table_reassign, make_state(predecessor_id_reassign, "predecessor.schedule", "live", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_state(authority_table_reassign, make_state(predecessor_id_reassign, "predecessor.destroy", "cleanup_scheduled", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_state(authority_table_reassign, make_state(old_id_reassign, "old.initialize.fresh", "uninitialized", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_state(authority_table_reassign, make_state(old_id_reassign, "old.read", "live", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_state(authority_table_reassign, make_state(old_id_reassign, "old.reassignment.schedule", "live", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_state(authority_table_reassign, make_state(old_id_reassign, "old.reassignment.destroy", "cleanup_scheduled", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_state(authority_table_reassign, make_state(replacement_id_reassign, "replacement.initialize", "uninitialized", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_state(authority_table_reassign, make_state(replacement_id_reassign, "replacement.read", "live", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_state(authority_table_reassign, make_state(replacement_id_reassign, "replacement.branch.join", "live", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_state(authority_table_reassign, make_state(replacement_id_reassign, "replacement.loop.header", "live", ctx), ctx);

    authority_table_reassign = authority.mir_resource_table_with_transition(authority_table_reassign, make_transition(predecessor_id_reassign, "initialize", "predecessor.initialize", "uninitialized", "live", "", "compiler/phase15_reassignment_source.gst:4:5", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_transition(authority_table_reassign, make_transition(predecessor_id_reassign, "move", "predecessor.move", "live", "moved", "", "compiler/phase15_reassignment_source.gst:5:5", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_transition(authority_table_reassign, make_transition(predecessor_id_reassign, "schedule_cleanup", "predecessor.schedule", "live", "cleanup_scheduled", predecessor_cleanup_id_reassign, "compiler/phase15_reassignment_source.gst:6:5", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_transition(authority_table_reassign, make_transition(predecessor_id_reassign, "invoke_destructor", "predecessor.destroy", "cleanup_scheduled", "destroyed", predecessor_cleanup_id_reassign, "compiler/phase15_reassignment_source.gst:7:5", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_transition(authority_table_reassign, make_transition(old_id_reassign, "initialize", "old.initialize.fresh", "uninitialized", "live", "", "compiler/phase15_reassignment_source.gst:10:5", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_transition(authority_table_reassign, make_transition(old_id_reassign, "use", "old.read", "live", "live", "", "compiler/phase15_reassignment_source.gst:11:5", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_transition(authority_table_reassign, make_transition(old_id_reassign, "schedule_cleanup", "old.reassignment.schedule", "live", "cleanup_scheduled", old_cleanup_id_reassign, "compiler/phase15_reassignment_source.gst:12:5", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_transition(authority_table_reassign, make_transition(old_id_reassign, "invoke_destructor", "old.reassignment.destroy", "cleanup_scheduled", "destroyed", old_cleanup_id_reassign, "compiler/phase15_reassignment_source.gst:13:5", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_transition(authority_table_reassign, make_transition(replacement_id_reassign, "initialize", "replacement.initialize", "uninitialized", "live", "", "compiler/phase15_reassignment_source.gst:20:5", ctx), ctx);
    authority_table_reassign = authority.mir_resource_table_with_transition(authority_table_reassign, make_transition(replacement_id_reassign, "use", "replacement.read", "live", "live", "", "compiler/phase15_reassignment_source.gst:21:5", ctx), ctx);

    mut resource_table_reassign := resource_mir.mir_resource_mir_make_empty_table(target_query_reassign.target.target_id, target_triple_reassign, ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_value(resource_table_reassign, make_value("mir.value.reassignment.predecessor", predecessor_id_reassign, resource_layout_reassign.layout_id, "compiler/phase15_reassignment_source.gst:4:5", "destroyed", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_value(resource_table_reassign, make_value("mir.value.reassignment.old", old_id_reassign, resource_layout_reassign.layout_id, "compiler/phase15_reassignment_source.gst:10:5", "destroyed", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_value(resource_table_reassign, make_value("mir.value.reassignment.replacement", replacement_id_reassign, resource_layout_reassign.layout_id, "compiler/phase15_reassignment_source.gst:20:5", "live", ctx), ctx);

    resource_table_reassign = resource_mir.mir_resource_mir_table_with_carrier(resource_table_reassign, make_carrier("carrier:reassignment:predecessor:source", predecessor_id_reassign, "mir.value.reassignment.predecessor", 0, "local:reassignment", "gust_reassignment_predecessor_source", resource_layout_reassign.layout_id, "compiler/phase15_reassignment_source.gst:4:5", "moved", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_carrier(resource_table_reassign, make_carrier("carrier:reassignment:predecessor:destination", predecessor_id_reassign, "mir.value.reassignment.predecessor", 0, "local:predecessor_destination", "gust_reassignment_predecessor_destination", resource_layout_reassign.layout_id, "compiler/phase15_reassignment_source.gst:5:5", "destroyed", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_carrier(resource_table_reassign, make_carrier("carrier:reassignment:old", old_id_reassign, "mir.value.reassignment.old", 0, "local:reassignment", "gust_reassignment_old", resource_layout_reassign.layout_id, "compiler/phase15_reassignment_source.gst:10:5", "destroyed", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_carrier(resource_table_reassign, make_carrier("carrier:reassignment:old:transfer", old_id_reassign, "mir.value.reassignment.old", 0, "local:reassignment_transfer", "gust_reassignment_old_transfer", resource_layout_reassign.layout_id, "compiler/phase15_reassignment_source.gst:12:5", "uninitialized", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_carrier(resource_table_reassign, make_carrier("carrier:reassignment:replacement", replacement_id_reassign, "mir.value.reassignment.replacement", 0, "local:reassignment", "gust_reassignment_replacement", resource_layout_reassign.layout_id, "compiler/phase15_reassignment_source.gst:20:5", "live", ctx), ctx);

    resource_table_reassign = resource_mir.mir_resource_mir_table_with_operation(resource_table_reassign, make_operation("operation:reassignment:predecessor:declare", 0, predecessor_id_reassign, "mir.value.reassignment.predecessor", "", "carrier:reassignment:predecessor:source", "predecessor.declare", "uninitialized", "uninitialized", "", "", "", "compiler/phase15_reassignment_source.gst:4:5", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_operation(resource_table_reassign, make_operation("operation:reassignment:predecessor:initialize", 1, predecessor_id_reassign, "mir.value.reassignment.predecessor", "", "carrier:reassignment:predecessor:source", "predecessor.initialize", "uninitialized", "live", "", "", "", "compiler/phase15_reassignment_source.gst:4:5", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_operation(resource_table_reassign, make_operation("operation:reassignment:predecessor:move", 3, predecessor_id_reassign, "mir.value.reassignment.predecessor", "carrier:reassignment:predecessor:source", "carrier:reassignment:predecessor:destination", "predecessor.move", "live", "moved", "", "", "", "compiler/phase15_reassignment_source.gst:5:5", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_operation(resource_table_reassign, make_operation("operation:reassignment:predecessor:schedule", 5, predecessor_id_reassign, "mir.value.reassignment.predecessor", "carrier:reassignment:predecessor:destination", "", "predecessor.schedule", "live", "cleanup_scheduled", predecessor_cleanup_id_reassign, "destructor:phase15:reassignment_resource", "", "compiler/phase15_reassignment_source.gst:6:5", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_operation(resource_table_reassign, make_operation("operation:reassignment:predecessor:destroy", 6, predecessor_id_reassign, "mir.value.reassignment.predecessor", "carrier:reassignment:predecessor:destination", "", "predecessor.destroy", "cleanup_scheduled", "destroyed", predecessor_cleanup_id_reassign, "destructor:phase15:reassignment_resource", "", "compiler/phase15_reassignment_source.gst:7:5", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_operation(resource_table_reassign, make_operation("operation:reassignment:old:initialize", 1, old_id_reassign, "mir.value.reassignment.old", "", "carrier:reassignment:old", "old.initialize.fresh", "uninitialized", "live", "", "", "", "compiler/phase15_reassignment_source.gst:10:5", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_operation(resource_table_reassign, make_operation("operation:reassignment:old:read", 2, old_id_reassign, "mir.value.reassignment.old", "carrier:reassignment:old", "", "old.read", "live", "live", "", "", "", "compiler/phase15_reassignment_source.gst:11:5", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_operation(resource_table_reassign, make_operation("operation:reassignment:old:schedule", 5, old_id_reassign, "mir.value.reassignment.old", "carrier:reassignment:old", "", "old.reassignment.schedule", "live", "cleanup_scheduled", old_cleanup_id_reassign, "destructor:phase15:reassignment_resource", "", "compiler/phase15_reassignment_source.gst:12:5", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_operation(resource_table_reassign, make_operation("operation:reassignment:old:destroy", 6, old_id_reassign, "mir.value.reassignment.old", "carrier:reassignment:old", "", "old.reassignment.destroy", "cleanup_scheduled", "destroyed", old_cleanup_id_reassign, "destructor:phase15:reassignment_resource", "", "compiler/phase15_reassignment_source.gst:13:5", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_operation(resource_table_reassign, make_operation("operation:reassignment:replacement:initialize", 1, replacement_id_reassign, "mir.value.reassignment.replacement", "", "carrier:reassignment:replacement", "replacement.initialize", "uninitialized", "live", "", "", "", "compiler/phase15_reassignment_source.gst:20:5", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_operation(resource_table_reassign, make_operation("operation:reassignment:replacement:read", 2, replacement_id_reassign, "mir.value.reassignment.replacement", "carrier:reassignment:replacement", "", "replacement.read", "live", "live", "", "", "", "compiler/phase15_reassignment_source.gst:21:5", ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_flow_edge(resource_table_reassign, make_flow_edge("edge:reassignment:branch", "block:reassignment:then", "block:reassignment:join", replacement_id_reassign, "mir.value.reassignment.replacement", "replacement.branch.join", 0, ctx), ctx);
    resource_table_reassign = resource_mir.mir_resource_mir_table_with_flow_edge(resource_table_reassign, make_flow_edge("edge:reassignment:loop", "block:reassignment:body", "block:reassignment:header", replacement_id_reassign, "mir.value.reassignment.replacement", "replacement.loop.header", 1, ctx), ctx);

    mut resource_validation_reassign := resource_mir.mir_resource_mir_table_validate(resource_table_reassign, authority_table_reassign, layout_table_reassign, ctx);
    if resource_validation_reassign.valid == 0 {
        fail(std.Concat("Phase 15.4 resource table rejected: ", resource_validation_reassign.reason_code));
    }

    mut reassignment_table_reassign := reassignment.mir_resource_reassignment_make_empty_table(ctx);
    mut replacement_reassign: reassignment.MirResourceReassignment[ctx];
    replacement_reassign.reassignment_id = std.Clone(ctx, "reassignment:phase15:live-local");
    replacement_reassign.form = std.Clone(ctx, "live_local");
    replacement_reassign.resolution_policy = std.Clone(ctx, "immediate_destroy");
    replacement_reassign.storage_id = std.Clone(ctx, "local:reassignment");
    replacement_reassign.old_resource_id = std.Clone(ctx, old_id_reassign);
    replacement_reassign.old_value_id = std.Clone(ctx, "mir.value.reassignment.old");
    replacement_reassign.old_carrier_id = std.Clone(ctx, "carrier:reassignment:old");
    replacement_reassign.replacement_resource_id = std.Clone(ctx, replacement_id_reassign);
    replacement_reassign.replacement_value_id = std.Clone(ctx, "mir.value.reassignment.replacement");
    replacement_reassign.replacement_carrier_id = std.Clone(ctx, "carrier:reassignment:replacement");
    replacement_reassign.predecessor_moved_resource_id = std.Clone(ctx, "");
    replacement_reassign.transfer_destination_carrier_id = std.Clone(ctx, "");
    replacement_reassign.cleanup_obligation_id = std.Clone(ctx, old_cleanup_id_reassign);
    replacement_reassign.destructor_id = std.Clone(ctx, "destructor:phase15:reassignment_resource");
    replacement_reassign.source_location = std.Clone(ctx, "compiler/phase15_reassignment_source.gst:20:5");
    replacement_reassign.control_flow_region = std.Clone(ctx, "");
    replacement_reassign.destruction_order = 1;
    replacement_reassign.mutable_storage = 1;
    replacement_reassign.old_prior_state = std.Clone(ctx, "live");
    replacement_reassign.old_resulting_state = std.Clone(ctx, "destroyed");
    replacement_reassign.replacement_prior_state = std.Clone(ctx, "uninitialized");
    replacement_reassign.replacement_resulting_state = std.Clone(ctx, "live");
    replacement_reassign.replacement_source_kind = std.Clone(ctx, "fresh_initialize");
    replacement_reassign.observable_effect = std.Clone(ctx, "destroy_old_then_publish_replacement");
    reassignment_table_reassign = reassignment.mir_resource_reassignment_table_with_entry(reassignment_table_reassign, replacement_reassign, ctx);

    mut reassignment_validation_reassign := reassignment.mir_resource_reassignment_validate(reassignment_table_reassign, resource_table_reassign, authority_table_reassign, ctx);
    if reassignment_validation_reassign.valid == 0 {
        fail(std.Concat("Phase 15.4 reassignment table rejected: ", reassignment_validation_reassign.reason_code));
    }
    mut reassignment_c_emission_reassign := reassignment_mir_to_c.mir_resource_reassignment_to_c_source(
        reassignment_table_reassign,
        resource_table_reassign,
        authority_table_reassign,
        ctx
    );
    if reassignment_c_emission_reassign.success == 0 {
        fail(std.Concat("Phase 15.4 MIR-to-C lowering rejected: ", reassignment_c_emission_reassign.reason_code));
    }

    mut request_reassign := resource_mir.mir_serialize_resource_mir_for_request(resource_table_reassign, authority_table_reassign, layout_table_reassign, ctx);
    request_reassign = reassignment.mir_resource_reassignment_append_to_request(request_reassign, reassignment_table_reassign, resource_table_reassign, authority_table_reassign, ctx);
    request_reassign = std.Concat(request_reassign, authority.mir_serialize_resource_authority_table_for_request(authority_table_reassign, layout_table_reassign, ctx));
    mut witness_reassign := mir_to_c.mir_resource_mir_to_c_witness(resource_table_reassign, authority_table_reassign, layout_table_reassign, ctx);
    witness_reassign = std.Concat(witness_reassign, reassignment.mir_resource_reassignment_witness(reassignment_table_reassign, resource_table_reassign, authority_table_reassign, ctx));
    witness_reassign = std.Concat(witness_reassign, reassignment_mir_to_c.mir_resource_reassignment_mir_to_c_witness(reassignment_table_reassign, resource_table_reassign, authority_table_reassign, ctx));
    if os.WriteFile("/tmp/gust-phase15-resource-reassignment.request", request_reassign) == 0 ||
       os.WriteFile("/tmp/gust-phase15-resource-reassignment.mir-to-c.witness", witness_reassign) == 0
    {
        fail("Phase 15.4 reassignment artifacts could not be written");
    }
    os.LogStr("SUCCESS: Phase 15.4 resource reassignment parity smoke passed");
}
