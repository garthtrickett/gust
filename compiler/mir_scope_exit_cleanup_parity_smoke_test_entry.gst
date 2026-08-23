import "mir_layout.gst" as layout;
import "mir_primitive_layout.gst" as primitive;
import "mir_resource_authority.gst" as authority;
import "mir_resource_value.gst" as resource_mir;
import "mir_resource_value_mir_to_c.gst" as resource_mir_to_c;
import "mir_scope_exit_cleanup.gst" as cleanup;
import "mir_scope_exit_cleanup_mir_to_c.gst" as cleanup_mir_to_c;

func fail(message: str) {
    os.LogStr(message);
    os.Exit(1);
}

func make_identity(resource_id: str, value_id: str, layout_id: str, declaration_id: str, owning_scope: str, source_location: str, target_id: str, target_triple: str, ctx: &Arena) authority.MirResourceIdentity[ctx] {
    mut identity_scope: authority.MirResourceIdentity[ctx];
    identity_scope.resource_id = std.Clone(ctx, resource_id);
    identity_scope.value_id = std.Clone(ctx, value_id);
    identity_scope.resource_type_id = std.Clone(ctx, "type:gust:Phase15ScopeExitResource");
    identity_scope.source_declaration_id = std.Clone(ctx, declaration_id);
    identity_scope.source_location = std.Clone(ctx, source_location);
    identity_scope.owning_function = std.Clone(ctx, "phase15_scope_exit_cleanup_fixture");
    identity_scope.owning_scope = std.Clone(ctx, owning_scope);
    identity_scope.resource_kind = std.Clone(ctx, "native_handle_resource");
    identity_scope.destructor_id = std.Clone(ctx, "destructor:phase15:scope_exit_resource");
    identity_scope.close_capability_id = std.Clone(ctx, "close:phase15:scope_exit_resource");
    identity_scope.copy_policy = std.Clone(ctx, "non_copy_resource");
    identity_scope.move_policy = std.Clone(ctx, "canonical_move_only");
    identity_scope.cleanup_policy = std.Clone(ctx, "compiler_owned_exactly_once_cleanup");
    identity_scope.target_id = std.Clone(ctx, target_id);
    identity_scope.target_triple = std.Clone(ctx, target_triple);
    identity_scope.layout_id = std.Clone(ctx, layout_id);
    return identity_scope;
}

func make_state(resource_id: str, program_point: str, state: str, ctx: &Arena) authority.MirResourceState[ctx] {
    mut state_scope: authority.MirResourceState[ctx];
    state_scope.resource_id = std.Clone(ctx, resource_id);
    state_scope.program_point = std.Clone(ctx, program_point);
    state_scope.state = std.Clone(ctx, state);
    return state_scope;
}

func make_transition(resource_id: str, operation: str, program_point: str, prior_state: str, resulting_state: str, cleanup_id: str, source_location: str, ctx: &Arena) authority.MirResourceTransition[ctx] {
    mut transition_scope: authority.MirResourceTransition[ctx];
    transition_scope.transition_id = authority.mir_resource_transition_id(resource_id, operation, program_point, ctx);
    transition_scope.resource_id = std.Clone(ctx, resource_id);
    transition_scope.prior_state = std.Clone(ctx, prior_state);
    transition_scope.operation = std.Clone(ctx, operation);
    transition_scope.resulting_state = std.Clone(ctx, resulting_state);
    transition_scope.program_point = std.Clone(ctx, program_point);
    transition_scope.source_location = std.Clone(ctx, source_location);
    transition_scope.control_flow_edge = std.Clone(ctx, "none");
    transition_scope.cleanup_id = std.Clone(ctx, cleanup_id);
    transition_scope.diagnostic_reason_code = std.Clone(ctx, "resource_transition_valid");
    return transition_scope;
}

func make_reference(reference_id: str, value_id: str, operation_id: str, resource_id: str, cleanup_id: str, ctx: &Arena) authority.MirResourceMirReference[ctx] {
    mut reference_scope: authority.MirResourceMirReference[ctx];
    reference_scope.reference_id = std.Clone(ctx, reference_id);
    reference_scope.mir_value_id = std.Clone(ctx, value_id);
    reference_scope.mir_operation_id = std.Clone(ctx, operation_id);
    reference_scope.resource_id = std.Clone(ctx, resource_id);
    reference_scope.cleanup_id = std.Clone(ctx, cleanup_id);
    return reference_scope;
}

func make_cleanup(cleanup_id: str, resource_id: str, destructor_id: str, scope_exit_id: str, insertion_scope: str, source_location: str, target_block: str, ctx: &Arena) authority.MirCleanupObligation[ctx] {
    mut cleanup_scope: authority.MirCleanupObligation[ctx];
    cleanup_scope.cleanup_id = std.Clone(ctx, cleanup_id);
    cleanup_scope.resource_id = std.Clone(ctx, resource_id);
    cleanup_scope.destructor_id = std.Clone(ctx, destructor_id);
    cleanup_scope.cleanup_reason = std.Clone(ctx, "normal_scope_exit");
    cleanup_scope.scope_exit_id = std.Clone(ctx, scope_exit_id);
    cleanup_scope.insertion_scope = std.Clone(ctx, insertion_scope);
    cleanup_scope.execution_order = 0;
    cleanup_scope.source_location = std.Clone(ctx, source_location);
    cleanup_scope.target_block = std.Clone(ctx, target_block);
    cleanup_scope.exactly_once = 1;
    cleanup_scope.manual_close_policy = std.Clone(ctx, "cancel_if_manually_closed");
    cleanup_scope.move_policy = std.Clone(ctx, "exclude_moved_identity");
    cleanup_scope.early_return_policy = std.Clone(ctx, "ordinary_exit_only");
    cleanup_scope.failure_policy = std.Clone(ctx, "selected_failure_cleanup_deferred");
    return cleanup_scope;
}

func make_value(value_id: str, resource_id: str, layout_id: str, owning_scope: str, source_location: str, current_state: str, ctx: &Arena) resource_mir.MirResourceValue[ctx] {
    mut value_scope: resource_mir.MirResourceValue[ctx];
    value_scope.value_id = std.Clone(ctx, value_id);
    value_scope.resource_id = std.Clone(ctx, resource_id);
    value_scope.resource_type_id = std.Clone(ctx, "type:gust:Phase15ScopeExitResource");
    value_scope.layout_id = std.Clone(ctx, layout_id);
    value_scope.owning_scope = std.Clone(ctx, owning_scope);
    value_scope.source_location = std.Clone(ctx, source_location);
    value_scope.current_state = std.Clone(ctx, current_state);
    value_scope.destructor_id = std.Clone(ctx, "destructor:phase15:scope_exit_resource");
    value_scope.close_capability_id = std.Clone(ctx, "close:phase15:scope_exit_resource");
    value_scope.cleanup_policy = std.Clone(ctx, "compiler_owned_exactly_once_cleanup");
    value_scope.copy_policy = std.Clone(ctx, "non_copy_resource");
    return value_scope;
}

func make_carrier(carrier_id: str, resource_id: str, value_id: str, owning_scope: str, storage_id: str, backend_symbol: str, layout_id: str, source_location: str, current_state: str, ctx: &Arena) resource_mir.MirResourceCarrier[ctx] {
    mut carrier_scope: resource_mir.MirResourceCarrier[ctx];
    carrier_scope.carrier_id = std.Clone(ctx, carrier_id);
    carrier_scope.resource_id = std.Clone(ctx, resource_id);
    carrier_scope.value_id = std.Clone(ctx, value_id);
    unsafe { carrier_scope.carrier_kind.tag = 0; }
    carrier_scope.storage_id = std.Clone(ctx, storage_id);
    carrier_scope.backend_symbol = std.Clone(ctx, backend_symbol);
    carrier_scope.owning_scope = std.Clone(ctx, owning_scope);
    carrier_scope.source_location = std.Clone(ctx, source_location);
    carrier_scope.resource_type_id = std.Clone(ctx, "type:gust:Phase15ScopeExitResource");
    carrier_scope.layout_id = std.Clone(ctx, layout_id);
    carrier_scope.current_state = std.Clone(ctx, current_state);
    return carrier_scope;
}

func make_operation(operation_id: str, kind_tag: int, resource_id: str, value_id: str, source_carrier_id: str, destination_carrier_id: str, program_point: str, prior_state: str, resulting_state: str, cleanup_id: str, destructor_id: str, close_capability_id: str, source_location: str, ctx: &Arena) resource_mir.MirResourceOperation[ctx] {
    mut operation_scope: resource_mir.MirResourceOperation[ctx];
    operation_scope.operation_id = std.Clone(ctx, operation_id);
    unsafe { operation_scope.operation_kind.tag = kind_tag; }
    operation_scope.resource_id = std.Clone(ctx, resource_id);
    operation_scope.value_id = std.Clone(ctx, value_id);
    operation_scope.source_carrier_id = std.Clone(ctx, source_carrier_id);
    operation_scope.destination_carrier_id = std.Clone(ctx, destination_carrier_id);
    operation_scope.program_point = std.Clone(ctx, program_point);
    operation_scope.prior_state = std.Clone(ctx, prior_state);
    operation_scope.resulting_state = std.Clone(ctx, resulting_state);
    operation_scope.cleanup_id = std.Clone(ctx, cleanup_id);
    operation_scope.destructor_id = std.Clone(ctx, destructor_id);
    operation_scope.close_capability_id = std.Clone(ctx, close_capability_id);
    operation_scope.source_location = std.Clone(ctx, source_location);
    return operation_scope;
}

func make_scope(scope_id: str, parent_scope_id: str, scope_kind: str, source_location: str, scope_exit_id: str, exit_program_point: str, depth: int, exit_sequence: int, ctx: &Arena) cleanup.MirResourceScope[ctx] {
    mut scope_fixture: cleanup.MirResourceScope[ctx];
    scope_fixture.scope_id = std.Clone(ctx, scope_id);
    scope_fixture.parent_scope_id = std.Clone(ctx, parent_scope_id);
    scope_fixture.scope_kind = std.Clone(ctx, scope_kind);
    scope_fixture.source_location = std.Clone(ctx, source_location);
    scope_fixture.scope_exit_id = std.Clone(ctx, scope_exit_id);
    scope_fixture.exit_program_point = std.Clone(ctx, exit_program_point);
    scope_fixture.depth = depth;
    scope_fixture.exit_sequence = exit_sequence;
    scope_fixture.selected = 1;
    return scope_fixture;
}

func make_binding(scope_id: str, resource_id: str, value_id: str, carrier_id: str, declaration_id: str, declaration_order: int, source_location: str, ctx: &Arena) cleanup.MirResourceScopeBinding[ctx] {
    mut binding_fixture: cleanup.MirResourceScopeBinding[ctx];
    binding_fixture.scope_id = std.Clone(ctx, scope_id);
    binding_fixture.resource_id = std.Clone(ctx, resource_id);
    binding_fixture.value_id = std.Clone(ctx, value_id);
    binding_fixture.carrier_id = std.Clone(ctx, carrier_id);
    binding_fixture.declaration_id = std.Clone(ctx, declaration_id);
    binding_fixture.declaration_order = declaration_order;
    binding_fixture.source_location = std.Clone(ctx, source_location);
    return binding_fixture;
}

func main() {
    mut ctx_scope := os.Arena.New();
    defer ctx_scope.Free();
    os.SetThreadScratch(ctx_scope);

    mut target_triple_scope := "x86_64-unknown-linux-gnu";
    mut target_query_scope := primitive.mir_primitive_layout_target(target_triple_scope, ctx_scope);
    if target_query_scope.found == 0 { fail("Phase 15.5 scope-exit target missing"); }
    mut layout_table_scope := primitive.mir_primitive_layout_table_for_target(target_triple_scope, ctx_scope);
    mut resource_layout_scope := layout.mir_layout_make_type_layout(
        "type:gust:Phase15ScopeExitResource",
        target_query_scope.target.target_id,
        "native_handle_resource",
        target_query_scope.target.pointer_size,
        target_query_scope.target.pointer_alignment,
        target_query_scope.target.pointer_size,
        ctx_scope
    );
    layout_table_scope = layout.mir_layout_table_with_layout(layout_table_scope, resource_layout_scope, ctx_scope);

    mut scope_function_id := "scope:phase15:scope-exit:function";
    mut scope_block_id := "scope:phase15:scope-exit:block";
    mut scope_nested_id := "scope:phase15:scope-exit:nested";
    mut scope_function_exit_id := "scope_exit:phase15:function";
    mut scope_block_exit_id := "scope_exit:phase15:block";
    mut scope_nested_exit_id := "scope_exit:phase15:nested";

    mut resource_block_first := authority.mir_resource_identity_id("phase15_scope_exit_cleanup_fixture", scope_block_id, "decl:block:first", 0, ctx_scope);
    mut resource_block_second := authority.mir_resource_identity_id("phase15_scope_exit_cleanup_fixture", scope_block_id, "decl:block:second", 1, ctx_scope);
    mut resource_block_moved := authority.mir_resource_identity_id("phase15_scope_exit_cleanup_fixture", scope_block_id, "decl:block:moved", 2, ctx_scope);
    mut resource_nested_live := authority.mir_resource_identity_id("phase15_scope_exit_cleanup_fixture", scope_nested_id, "decl:nested:live", 3, ctx_scope);
    mut resource_nested_destroyed := authority.mir_resource_identity_id("phase15_scope_exit_cleanup_fixture", scope_nested_id, "decl:nested:destroyed", 4, ctx_scope);
    mut resource_function_first := authority.mir_resource_identity_id("phase15_scope_exit_cleanup_fixture", scope_function_id, "decl:function:first", 5, ctx_scope);
    mut resource_function_second := authority.mir_resource_identity_id("phase15_scope_exit_cleanup_fixture", scope_function_id, "decl:function:second", 6, ctx_scope);
    mut resource_function_closed := authority.mir_resource_identity_id("phase15_scope_exit_cleanup_fixture", scope_function_id, "decl:function:closed", 7, ctx_scope);

    mut cleanup_block_first := authority.mir_cleanup_obligation_id(resource_block_first, scope_block_exit_id, 0, ctx_scope);
    mut cleanup_block_second := authority.mir_cleanup_obligation_id(resource_block_second, scope_block_exit_id, 1, ctx_scope);
    mut cleanup_nested_live := authority.mir_cleanup_obligation_id(resource_nested_live, scope_nested_exit_id, 2, ctx_scope);
    mut cleanup_nested_destroyed := authority.mir_cleanup_obligation_id(resource_nested_destroyed, "scope_exit:phase15:prior", 3, ctx_scope);
    mut cleanup_function_first := authority.mir_cleanup_obligation_id(resource_function_first, scope_function_exit_id, 4, ctx_scope);
    mut cleanup_function_second := authority.mir_cleanup_obligation_id(resource_function_second, scope_function_exit_id, 5, ctx_scope);

    mut authority_table_scope_pre := authority.mir_resource_make_empty_table(target_query_scope.target.target_id, target_triple_scope, ctx_scope);
    mut destructor_scope: authority.MirDestructorIdentity[ctx_scope];
    destructor_scope.destructor_id = std.Clone(ctx_scope, "destructor:phase15:scope_exit_resource");
    destructor_scope.resource_type_id = std.Clone(ctx_scope, "type:gust:Phase15ScopeExitResource");
    destructor_scope.runtime_symbol = std.Clone(ctx_scope, "gust_phase15_scope_exit_resource_destroy");
    destructor_scope.descriptor_id = std.Clone(ctx_scope, "descriptor:phase15:scope_exit_resource");
    destructor_scope.target_id = std.Clone(ctx_scope, target_query_scope.target.target_id);
    destructor_scope.target_triple = std.Clone(ctx_scope, target_triple_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_destructor(authority_table_scope_pre, destructor_scope, ctx_scope);

    mut close_scope: authority.MirCloseCapability[ctx_scope];
    close_scope.close_capability_id = std.Clone(ctx_scope, "close:phase15:scope_exit_resource");
    close_scope.resource_type_id = std.Clone(ctx_scope, "type:gust:Phase15ScopeExitResource");
    close_scope.runtime_symbol = std.Clone(ctx_scope, "gust_phase15_scope_exit_resource_close");
    close_scope.suppresses_deferred_cleanup = 1;
    close_scope.repeated_close_policy = std.Clone(ctx_scope, "reject");
    close_scope.target_id = std.Clone(ctx_scope, target_query_scope.target.target_id);
    close_scope.target_triple = std.Clone(ctx_scope, target_triple_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_close_capability(authority_table_scope_pre, close_scope, ctx_scope);

    authority_table_scope_pre = authority.mir_resource_table_with_resource(authority_table_scope_pre, make_identity(resource_block_first, "mir.value.scope.block.first", resource_layout_scope.layout_id, "decl:block:first", scope_block_id, "compiler/phase15_scope_exit_source.gst:5:9", target_query_scope.target.target_id, target_triple_scope, ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_resource(authority_table_scope_pre, make_identity(resource_block_second, "mir.value.scope.block.second", resource_layout_scope.layout_id, "decl:block:second", scope_block_id, "compiler/phase15_scope_exit_source.gst:6:9", target_query_scope.target.target_id, target_triple_scope, ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_resource(authority_table_scope_pre, make_identity(resource_block_moved, "mir.value.scope.block.moved", resource_layout_scope.layout_id, "decl:block:moved", scope_block_id, "compiler/phase15_scope_exit_source.gst:7:9", target_query_scope.target.target_id, target_triple_scope, ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_resource(authority_table_scope_pre, make_identity(resource_nested_live, "mir.value.scope.nested.live", resource_layout_scope.layout_id, "decl:nested:live", scope_nested_id, "compiler/phase15_scope_exit_source.gst:10:13", target_query_scope.target.target_id, target_triple_scope, ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_resource(authority_table_scope_pre, make_identity(resource_nested_destroyed, "mir.value.scope.nested.destroyed", resource_layout_scope.layout_id, "decl:nested:destroyed", scope_nested_id, "compiler/phase15_scope_exit_source.gst:11:13", target_query_scope.target.target_id, target_triple_scope, ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_resource(authority_table_scope_pre, make_identity(resource_function_first, "mir.value.scope.function.first", resource_layout_scope.layout_id, "decl:function:first", scope_function_id, "compiler/phase15_scope_exit_source.gst:2:5", target_query_scope.target.target_id, target_triple_scope, ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_resource(authority_table_scope_pre, make_identity(resource_function_second, "mir.value.scope.function.second", resource_layout_scope.layout_id, "decl:function:second", scope_function_id, "compiler/phase15_scope_exit_source.gst:3:5", target_query_scope.target.target_id, target_triple_scope, ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_resource(authority_table_scope_pre, make_identity(resource_function_closed, "mir.value.scope.function.closed", resource_layout_scope.layout_id, "decl:function:closed", scope_function_id, "compiler/phase15_scope_exit_source.gst:4:5", target_query_scope.target.target_id, target_triple_scope, ctx_scope), ctx_scope);

    authority_table_scope_pre = authority.mir_resource_table_with_cleanup(authority_table_scope_pre, make_cleanup(cleanup_block_first, resource_block_first, "destructor:phase15:scope_exit_resource", scope_block_exit_id, scope_block_id, "compiler/phase15_scope_exit_source.gst:5:9", "block:scope-exit:block", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_cleanup(authority_table_scope_pre, make_cleanup(cleanup_block_second, resource_block_second, "destructor:phase15:scope_exit_resource", scope_block_exit_id, scope_block_id, "compiler/phase15_scope_exit_source.gst:6:9", "block:scope-exit:block", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_cleanup(authority_table_scope_pre, make_cleanup(cleanup_nested_live, resource_nested_live, "destructor:phase15:scope_exit_resource", scope_nested_exit_id, scope_nested_id, "compiler/phase15_scope_exit_source.gst:10:13", "block:scope-exit:nested", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_cleanup(authority_table_scope_pre, make_cleanup(cleanup_nested_destroyed, resource_nested_destroyed, "destructor:phase15:scope_exit_resource", "scope_exit:phase15:prior", scope_nested_id, "compiler/phase15_scope_exit_source.gst:11:13", "block:scope-exit:prior", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_cleanup(authority_table_scope_pre, make_cleanup(cleanup_function_first, resource_function_first, "destructor:phase15:scope_exit_resource", scope_function_exit_id, scope_function_id, "compiler/phase15_scope_exit_source.gst:2:5", "block:scope-exit:function", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_cleanup(authority_table_scope_pre, make_cleanup(cleanup_function_second, resource_function_second, "destructor:phase15:scope_exit_resource", scope_function_exit_id, scope_function_id, "compiler/phase15_scope_exit_source.gst:3:5", "block:scope-exit:function", ctx_scope), ctx_scope);

    authority_table_scope_pre = authority.mir_resource_table_with_mir_reference(authority_table_scope_pre, make_reference("reference:scope:block:first", "mir.value.scope.block.first", "operation:scope:block:first:initialize", resource_block_first, "", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_mir_reference(authority_table_scope_pre, make_reference("reference:scope:block:second", "mir.value.scope.block.second", "operation:scope:block:second:initialize", resource_block_second, "", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_mir_reference(authority_table_scope_pre, make_reference("reference:scope:block:moved", "mir.value.scope.block.moved", "operation:scope:block:moved:move", resource_block_moved, "", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_mir_reference(authority_table_scope_pre, make_reference("reference:scope:nested:live", "mir.value.scope.nested.live", "operation:scope:nested:live:initialize", resource_nested_live, "", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_mir_reference(authority_table_scope_pre, make_reference("reference:scope:nested:destroyed", "mir.value.scope.nested.destroyed", "operation:scope:nested:destroyed:destroy", resource_nested_destroyed, "", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_mir_reference(authority_table_scope_pre, make_reference("reference:scope:function:first", "mir.value.scope.function.first", "operation:scope:function:first:initialize", resource_function_first, "", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_mir_reference(authority_table_scope_pre, make_reference("reference:scope:function:second", "mir.value.scope.function.second", "operation:scope:function:second:initialize", resource_function_second, "", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_mir_reference(authority_table_scope_pre, make_reference("reference:scope:function:closed", "mir.value.scope.function.closed", "operation:scope:function:closed:close", resource_function_closed, "", ctx_scope), ctx_scope);

    authority_table_scope_pre = authority.mir_resource_table_with_mir_reference(authority_table_scope_pre, make_reference("reference:cleanup:block:first", "mir.value.scope.block.first", std.Concat("operation:scope-exit:schedule:", cleanup_block_first), resource_block_first, cleanup_block_first, ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_mir_reference(authority_table_scope_pre, make_reference("reference:cleanup:block:second", "mir.value.scope.block.second", std.Concat("operation:scope-exit:schedule:", cleanup_block_second), resource_block_second, cleanup_block_second, ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_mir_reference(authority_table_scope_pre, make_reference("reference:cleanup:nested:live", "mir.value.scope.nested.live", std.Concat("operation:scope-exit:schedule:", cleanup_nested_live), resource_nested_live, cleanup_nested_live, ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_mir_reference(authority_table_scope_pre, make_reference("reference:cleanup:nested:destroyed", "mir.value.scope.nested.destroyed", "operation:scope:nested:destroyed:schedule", resource_nested_destroyed, cleanup_nested_destroyed, ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_mir_reference(authority_table_scope_pre, make_reference("reference:cleanup:function:first", "mir.value.scope.function.first", std.Concat("operation:scope-exit:schedule:", cleanup_function_first), resource_function_first, cleanup_function_first, ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_mir_reference(authority_table_scope_pre, make_reference("reference:cleanup:function:second", "mir.value.scope.function.second", std.Concat("operation:scope-exit:schedule:", cleanup_function_second), resource_function_second, cleanup_function_second, ctx_scope), ctx_scope);

    // Initial states and transitions. Selected live resources stop at live here;
    // the compiler-owned plan below inserts their schedule/destructor operations.
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_block_first, "scope.block.first.declare", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_block_first, "scope.block.first.initialize", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_block_first, "scope.block.first.live", "live", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_transition(authority_table_scope_pre, make_transition(resource_block_first, "initialize", "scope.block.first.initialize", "uninitialized", "live", "", "compiler/phase15_scope_exit_source.gst:5:9", ctx_scope), ctx_scope);

    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_block_second, "scope.block.second.declare", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_block_second, "scope.block.second.initialize", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_block_second, "scope.block.second.live", "live", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_transition(authority_table_scope_pre, make_transition(resource_block_second, "initialize", "scope.block.second.initialize", "uninitialized", "live", "", "compiler/phase15_scope_exit_source.gst:6:9", ctx_scope), ctx_scope);

    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_block_moved, "scope.block.moved.declare", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_block_moved, "scope.block.moved.initialize", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_block_moved, "scope.block.moved.move", "live", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_block_moved, "scope.block.moved.final", "moved", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_transition(authority_table_scope_pre, make_transition(resource_block_moved, "initialize", "scope.block.moved.initialize", "uninitialized", "live", "", "compiler/phase15_scope_exit_source.gst:7:9", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_transition(authority_table_scope_pre, make_transition(resource_block_moved, "move", "scope.block.moved.move", "live", "moved", "", "compiler/phase15_scope_exit_source.gst:8:9", ctx_scope), ctx_scope);

    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_nested_live, "scope.nested.live.declare", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_nested_live, "scope.nested.live.initialize", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_nested_live, "scope.nested.live.final", "live", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_transition(authority_table_scope_pre, make_transition(resource_nested_live, "initialize", "scope.nested.live.initialize", "uninitialized", "live", "", "compiler/phase15_scope_exit_source.gst:10:13", ctx_scope), ctx_scope);

    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_nested_destroyed, "scope.nested.destroyed.declare", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_nested_destroyed, "scope.nested.destroyed.initialize", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_nested_destroyed, "scope.nested.destroyed.schedule", "live", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_nested_destroyed, "scope.nested.destroyed.destroy", "cleanup_scheduled", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_nested_destroyed, "scope.nested.destroyed.final", "destroyed", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_transition(authority_table_scope_pre, make_transition(resource_nested_destroyed, "initialize", "scope.nested.destroyed.initialize", "uninitialized", "live", "", "compiler/phase15_scope_exit_source.gst:11:13", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_transition(authority_table_scope_pre, make_transition(resource_nested_destroyed, "schedule_cleanup", "scope.nested.destroyed.schedule", "live", "cleanup_scheduled", cleanup_nested_destroyed, "compiler/phase15_scope_exit_source.gst:11:13", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_transition(authority_table_scope_pre, make_transition(resource_nested_destroyed, "invoke_destructor", "scope.nested.destroyed.destroy", "cleanup_scheduled", "destroyed", cleanup_nested_destroyed, "compiler/phase15_scope_exit_source.gst:11:13", ctx_scope), ctx_scope);

    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_function_first, "scope.function.first.declare", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_function_first, "scope.function.first.initialize", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_function_first, "scope.function.first.final", "live", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_transition(authority_table_scope_pre, make_transition(resource_function_first, "initialize", "scope.function.first.initialize", "uninitialized", "live", "", "compiler/phase15_scope_exit_source.gst:2:5", ctx_scope), ctx_scope);

    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_function_second, "scope.function.second.declare", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_function_second, "scope.function.second.initialize", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_function_second, "scope.function.second.final", "live", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_transition(authority_table_scope_pre, make_transition(resource_function_second, "initialize", "scope.function.second.initialize", "uninitialized", "live", "", "compiler/phase15_scope_exit_source.gst:3:5", ctx_scope), ctx_scope);

    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_function_closed, "scope.function.closed.declare", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_function_closed, "scope.function.closed.initialize", "uninitialized", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_function_closed, "scope.function.closed.close", "live", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_state(authority_table_scope_pre, make_state(resource_function_closed, "scope.function.closed.final", "manually_closed", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_transition(authority_table_scope_pre, make_transition(resource_function_closed, "initialize", "scope.function.closed.initialize", "uninitialized", "live", "", "compiler/phase15_scope_exit_source.gst:4:5", ctx_scope), ctx_scope);
    authority_table_scope_pre = authority.mir_resource_table_with_transition(authority_table_scope_pre, make_transition(resource_function_closed, "manual_close", "scope.function.closed.close", "live", "manually_closed", "", "compiler/phase15_scope_exit_source.gst:4:5", ctx_scope), ctx_scope);

    mut resource_table_scope_pre := resource_mir.mir_resource_mir_make_empty_table(target_query_scope.target.target_id, target_triple_scope, ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_value(resource_table_scope_pre, make_value("mir.value.scope.block.first", resource_block_first, resource_layout_scope.layout_id, scope_block_id, "compiler/phase15_scope_exit_source.gst:5:9", "live", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_value(resource_table_scope_pre, make_value("mir.value.scope.block.second", resource_block_second, resource_layout_scope.layout_id, scope_block_id, "compiler/phase15_scope_exit_source.gst:6:9", "live", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_value(resource_table_scope_pre, make_value("mir.value.scope.block.moved", resource_block_moved, resource_layout_scope.layout_id, scope_block_id, "compiler/phase15_scope_exit_source.gst:7:9", "moved", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_value(resource_table_scope_pre, make_value("mir.value.scope.nested.live", resource_nested_live, resource_layout_scope.layout_id, scope_nested_id, "compiler/phase15_scope_exit_source.gst:10:13", "live", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_value(resource_table_scope_pre, make_value("mir.value.scope.nested.destroyed", resource_nested_destroyed, resource_layout_scope.layout_id, scope_nested_id, "compiler/phase15_scope_exit_source.gst:11:13", "destroyed", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_value(resource_table_scope_pre, make_value("mir.value.scope.function.first", resource_function_first, resource_layout_scope.layout_id, scope_function_id, "compiler/phase15_scope_exit_source.gst:2:5", "live", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_value(resource_table_scope_pre, make_value("mir.value.scope.function.second", resource_function_second, resource_layout_scope.layout_id, scope_function_id, "compiler/phase15_scope_exit_source.gst:3:5", "live", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_value(resource_table_scope_pre, make_value("mir.value.scope.function.closed", resource_function_closed, resource_layout_scope.layout_id, scope_function_id, "compiler/phase15_scope_exit_source.gst:4:5", "manually_closed", ctx_scope), ctx_scope);

    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_carrier(resource_table_scope_pre, make_carrier("carrier:scope:block:first", resource_block_first, "mir.value.scope.block.first", scope_block_id, "local:scope:block:first", "gust_scope_block_first", resource_layout_scope.layout_id, "compiler/phase15_scope_exit_source.gst:5:9", "live", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_carrier(resource_table_scope_pre, make_carrier("carrier:scope:block:second", resource_block_second, "mir.value.scope.block.second", scope_block_id, "local:scope:block:second", "gust_scope_block_second", resource_layout_scope.layout_id, "compiler/phase15_scope_exit_source.gst:6:9", "live", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_carrier(resource_table_scope_pre, make_carrier("carrier:scope:block:moved:source", resource_block_moved, "mir.value.scope.block.moved", scope_block_id, "local:scope:block:moved", "gust_scope_block_moved", resource_layout_scope.layout_id, "compiler/phase15_scope_exit_source.gst:7:9", "moved", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_carrier(resource_table_scope_pre, make_carrier("carrier:scope:block:moved:destination", resource_block_moved, "mir.value.scope.block.moved", scope_block_id, "local:scope:moved:destination", "gust_scope_moved_destination", resource_layout_scope.layout_id, "compiler/phase15_scope_exit_source.gst:8:9", "live", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_carrier(resource_table_scope_pre, make_carrier("carrier:scope:nested:live", resource_nested_live, "mir.value.scope.nested.live", scope_nested_id, "local:scope:nested:live", "gust_scope_nested_live", resource_layout_scope.layout_id, "compiler/phase15_scope_exit_source.gst:10:13", "live", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_carrier(resource_table_scope_pre, make_carrier("carrier:scope:nested:destroyed", resource_nested_destroyed, "mir.value.scope.nested.destroyed", scope_nested_id, "local:scope:nested:destroyed", "gust_scope_nested_destroyed", resource_layout_scope.layout_id, "compiler/phase15_scope_exit_source.gst:11:13", "destroyed", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_carrier(resource_table_scope_pre, make_carrier("carrier:scope:function:first", resource_function_first, "mir.value.scope.function.first", scope_function_id, "local:scope:function:first", "gust_scope_function_first", resource_layout_scope.layout_id, "compiler/phase15_scope_exit_source.gst:2:5", "live", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_carrier(resource_table_scope_pre, make_carrier("carrier:scope:function:second", resource_function_second, "mir.value.scope.function.second", scope_function_id, "local:scope:function:second", "gust_scope_function_second", resource_layout_scope.layout_id, "compiler/phase15_scope_exit_source.gst:3:5", "live", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_carrier(resource_table_scope_pre, make_carrier("carrier:scope:function:closed", resource_function_closed, "mir.value.scope.function.closed", scope_function_id, "local:scope:function:closed", "gust_scope_function_closed", resource_layout_scope.layout_id, "compiler/phase15_scope_exit_source.gst:4:5", "manually_closed", ctx_scope), ctx_scope);

    // Declare/initialize every resource, then model the three exclusions.
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:block:first:declare", 0, resource_block_first, "mir.value.scope.block.first", "", "carrier:scope:block:first", "scope.block.first.declare", "uninitialized", "uninitialized", "", "", "", "compiler/phase15_scope_exit_source.gst:5:9", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:block:first:initialize", 1, resource_block_first, "mir.value.scope.block.first", "", "carrier:scope:block:first", "scope.block.first.initialize", "uninitialized", "live", "", "", "", "compiler/phase15_scope_exit_source.gst:5:9", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:block:second:declare", 0, resource_block_second, "mir.value.scope.block.second", "", "carrier:scope:block:second", "scope.block.second.declare", "uninitialized", "uninitialized", "", "", "", "compiler/phase15_scope_exit_source.gst:6:9", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:block:second:initialize", 1, resource_block_second, "mir.value.scope.block.second", "", "carrier:scope:block:second", "scope.block.second.initialize", "uninitialized", "live", "", "", "", "compiler/phase15_scope_exit_source.gst:6:9", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:block:moved:declare", 0, resource_block_moved, "mir.value.scope.block.moved", "", "carrier:scope:block:moved:source", "scope.block.moved.declare", "uninitialized", "uninitialized", "", "", "", "compiler/phase15_scope_exit_source.gst:7:9", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:block:moved:initialize", 1, resource_block_moved, "mir.value.scope.block.moved", "", "carrier:scope:block:moved:source", "scope.block.moved.initialize", "uninitialized", "live", "", "", "", "compiler/phase15_scope_exit_source.gst:7:9", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:block:moved:move", 3, resource_block_moved, "mir.value.scope.block.moved", "carrier:scope:block:moved:source", "carrier:scope:block:moved:destination", "scope.block.moved.move", "live", "moved", "", "", "", "compiler/phase15_scope_exit_source.gst:8:9", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:nested:live:declare", 0, resource_nested_live, "mir.value.scope.nested.live", "", "carrier:scope:nested:live", "scope.nested.live.declare", "uninitialized", "uninitialized", "", "", "", "compiler/phase15_scope_exit_source.gst:10:13", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:nested:live:initialize", 1, resource_nested_live, "mir.value.scope.nested.live", "", "carrier:scope:nested:live", "scope.nested.live.initialize", "uninitialized", "live", "", "", "", "compiler/phase15_scope_exit_source.gst:10:13", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:nested:destroyed:declare", 0, resource_nested_destroyed, "mir.value.scope.nested.destroyed", "", "carrier:scope:nested:destroyed", "scope.nested.destroyed.declare", "uninitialized", "uninitialized", "", "", "", "compiler/phase15_scope_exit_source.gst:11:13", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:nested:destroyed:initialize", 1, resource_nested_destroyed, "mir.value.scope.nested.destroyed", "", "carrier:scope:nested:destroyed", "scope.nested.destroyed.initialize", "uninitialized", "live", "", "", "", "compiler/phase15_scope_exit_source.gst:11:13", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:nested:destroyed:schedule", 5, resource_nested_destroyed, "mir.value.scope.nested.destroyed", "carrier:scope:nested:destroyed", "", "scope.nested.destroyed.schedule", "live", "cleanup_scheduled", cleanup_nested_destroyed, "destructor:phase15:scope_exit_resource", "", "compiler/phase15_scope_exit_source.gst:11:13", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:nested:destroyed:destroy", 6, resource_nested_destroyed, "mir.value.scope.nested.destroyed", "carrier:scope:nested:destroyed", "", "scope.nested.destroyed.destroy", "cleanup_scheduled", "destroyed", cleanup_nested_destroyed, "destructor:phase15:scope_exit_resource", "", "compiler/phase15_scope_exit_source.gst:11:13", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:function:first:declare", 0, resource_function_first, "mir.value.scope.function.first", "", "carrier:scope:function:first", "scope.function.first.declare", "uninitialized", "uninitialized", "", "", "", "compiler/phase15_scope_exit_source.gst:2:5", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:function:first:initialize", 1, resource_function_first, "mir.value.scope.function.first", "", "carrier:scope:function:first", "scope.function.first.initialize", "uninitialized", "live", "", "", "", "compiler/phase15_scope_exit_source.gst:2:5", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:function:second:declare", 0, resource_function_second, "mir.value.scope.function.second", "", "carrier:scope:function:second", "scope.function.second.declare", "uninitialized", "uninitialized", "", "", "", "compiler/phase15_scope_exit_source.gst:3:5", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:function:second:initialize", 1, resource_function_second, "mir.value.scope.function.second", "", "carrier:scope:function:second", "scope.function.second.initialize", "uninitialized", "live", "", "", "", "compiler/phase15_scope_exit_source.gst:3:5", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:function:closed:declare", 0, resource_function_closed, "mir.value.scope.function.closed", "", "carrier:scope:function:closed", "scope.function.closed.declare", "uninitialized", "uninitialized", "", "", "", "compiler/phase15_scope_exit_source.gst:4:5", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:function:closed:initialize", 1, resource_function_closed, "mir.value.scope.function.closed", "", "carrier:scope:function:closed", "scope.function.closed.initialize", "uninitialized", "live", "", "", "", "compiler/phase15_scope_exit_source.gst:4:5", ctx_scope), ctx_scope);
    resource_table_scope_pre = resource_mir.mir_resource_mir_table_with_operation(resource_table_scope_pre, make_operation("operation:scope:function:closed:close", 4, resource_function_closed, "mir.value.scope.function.closed", "carrier:scope:function:closed", "", "scope.function.closed.close", "live", "manually_closed", "", "", "close:phase15:scope_exit_resource", "compiler/phase15_scope_exit_source.gst:4:5", ctx_scope), ctx_scope);

    mut scope_table_scope := cleanup.mir_scope_exit_cleanup_make_scope_table(ctx_scope);
    scope_table_scope = cleanup.mir_scope_exit_cleanup_table_with_scope(scope_table_scope, make_scope(scope_function_id, "", "function_body", "compiler/phase15_scope_exit_source.gst:1:1", scope_function_exit_id, "scope.function.exit", 0, 3, ctx_scope), ctx_scope);
    scope_table_scope = cleanup.mir_scope_exit_cleanup_table_with_scope(scope_table_scope, make_scope(scope_block_id, scope_function_id, "block_scope", "compiler/phase15_scope_exit_source.gst:5:5", scope_block_exit_id, "scope.block.exit", 1, 1, ctx_scope), ctx_scope);
    scope_table_scope = cleanup.mir_scope_exit_cleanup_table_with_scope(scope_table_scope, make_scope(scope_nested_id, scope_block_id, "selected_nested_scope", "compiler/phase15_scope_exit_source.gst:9:9", scope_nested_exit_id, "scope.nested.exit", 2, 2, ctx_scope), ctx_scope);

    scope_table_scope = cleanup.mir_scope_exit_cleanup_table_with_binding(scope_table_scope, make_binding(scope_block_id, resource_block_first, "mir.value.scope.block.first", "carrier:scope:block:first", "decl:block:first", 1, "compiler/phase15_scope_exit_source.gst:5:9", ctx_scope), ctx_scope);
    scope_table_scope = cleanup.mir_scope_exit_cleanup_table_with_binding(scope_table_scope, make_binding(scope_block_id, resource_block_second, "mir.value.scope.block.second", "carrier:scope:block:second", "decl:block:second", 2, "compiler/phase15_scope_exit_source.gst:6:9", ctx_scope), ctx_scope);
    scope_table_scope = cleanup.mir_scope_exit_cleanup_table_with_binding(scope_table_scope, make_binding(scope_block_id, resource_block_moved, "mir.value.scope.block.moved", "carrier:scope:block:moved:source", "decl:block:moved", 3, "compiler/phase15_scope_exit_source.gst:7:9", ctx_scope), ctx_scope);
    scope_table_scope = cleanup.mir_scope_exit_cleanup_table_with_binding(scope_table_scope, make_binding(scope_nested_id, resource_nested_live, "mir.value.scope.nested.live", "carrier:scope:nested:live", "decl:nested:live", 1, "compiler/phase15_scope_exit_source.gst:10:13", ctx_scope), ctx_scope);
    scope_table_scope = cleanup.mir_scope_exit_cleanup_table_with_binding(scope_table_scope, make_binding(scope_nested_id, resource_nested_destroyed, "mir.value.scope.nested.destroyed", "carrier:scope:nested:destroyed", "decl:nested:destroyed", 2, "compiler/phase15_scope_exit_source.gst:11:13", ctx_scope), ctx_scope);
    scope_table_scope = cleanup.mir_scope_exit_cleanup_table_with_binding(scope_table_scope, make_binding(scope_function_id, resource_function_first, "mir.value.scope.function.first", "carrier:scope:function:first", "decl:function:first", 1, "compiler/phase15_scope_exit_source.gst:2:5", ctx_scope), ctx_scope);
    scope_table_scope = cleanup.mir_scope_exit_cleanup_table_with_binding(scope_table_scope, make_binding(scope_function_id, resource_function_second, "mir.value.scope.function.second", "carrier:scope:function:second", "decl:function:second", 2, "compiler/phase15_scope_exit_source.gst:3:5", ctx_scope), ctx_scope);
    scope_table_scope = cleanup.mir_scope_exit_cleanup_table_with_binding(scope_table_scope, make_binding(scope_function_id, resource_function_closed, "mir.value.scope.function.closed", "carrier:scope:function:closed", "decl:function:closed", 3, "compiler/phase15_scope_exit_source.gst:4:5", ctx_scope), ctx_scope);

    mut plan_result_scope := cleanup.mir_scope_exit_cleanup_plan_build(
        scope_table_scope,
        resource_table_scope_pre,
        authority_table_scope_pre,
        ctx_scope
    );
    if plan_result_scope.valid == 0 {
        fail(std.Concat("Phase 15.5 cleanup planning rejected: ", plan_result_scope.reason_code));
    }

    mut authority_table_scope := authority_table_scope_pre;
    mut resource_table_scope := resource_table_scope_pre;
    mut apply_scope_index := 0;
    while apply_scope_index < cleanup.mir_scope_exit_cleanup_entry_count(plan_result_scope.plan, ctx_scope) {
        mut apply_scope_entry := cleanup.mir_scope_exit_cleanup_entry_at(plan_result_scope.plan, apply_scope_index, ctx_scope);
        mut apply_scope_schedule := make_operation(
            apply_scope_entry.schedule_operation_id,
            5,
            apply_scope_entry.resource_id,
            apply_scope_entry.value_id,
            apply_scope_entry.carrier_id,
            "",
            std.Concat(apply_scope_entry.exit_program_point, ".schedule"),
            "live",
            "cleanup_scheduled",
            apply_scope_entry.cleanup_obligation_id,
            apply_scope_entry.destructor_id,
            "",
            apply_scope_entry.source_location,
            ctx_scope
        );
        mut apply_scope_destroy := make_operation(
            apply_scope_entry.cleanup_operation_id,
            6,
            apply_scope_entry.resource_id,
            apply_scope_entry.value_id,
            apply_scope_entry.carrier_id,
            "",
            apply_scope_entry.exit_program_point,
            "cleanup_scheduled",
            "destroyed",
            apply_scope_entry.cleanup_obligation_id,
            apply_scope_entry.destructor_id,
            "",
            apply_scope_entry.source_location,
            ctx_scope
        );
        resource_table_scope = resource_mir.mir_resource_mir_apply_scope_exit_cleanup(
            resource_table_scope,
            apply_scope_schedule,
            apply_scope_destroy,
            ctx_scope
        );
        authority_table_scope = authority.mir_resource_table_with_state(authority_table_scope, make_state(apply_scope_entry.resource_id, std.Concat(apply_scope_entry.exit_program_point, ".schedule"), "live", ctx_scope), ctx_scope);
        authority_table_scope = authority.mir_resource_table_with_transition(authority_table_scope, make_transition(apply_scope_entry.resource_id, "schedule_cleanup", std.Concat(apply_scope_entry.exit_program_point, ".schedule"), "live", "cleanup_scheduled", apply_scope_entry.cleanup_obligation_id, apply_scope_entry.source_location, ctx_scope), ctx_scope);
        authority_table_scope = authority.mir_resource_table_with_state(authority_table_scope, make_state(apply_scope_entry.resource_id, apply_scope_entry.exit_program_point, "cleanup_scheduled", ctx_scope), ctx_scope);
        authority_table_scope = authority.mir_resource_table_with_transition(authority_table_scope, make_transition(apply_scope_entry.resource_id, "invoke_destructor", apply_scope_entry.exit_program_point, "cleanup_scheduled", "destroyed", apply_scope_entry.cleanup_obligation_id, apply_scope_entry.source_location, ctx_scope), ctx_scope);
        authority_table_scope = authority.mir_resource_table_with_state(authority_table_scope, make_state(apply_scope_entry.resource_id, std.Concat(apply_scope_entry.exit_program_point, ".final"), "destroyed", ctx_scope), ctx_scope);
        apply_scope_index = apply_scope_index + 1;
    }

    mut cleanup_validation_scope := cleanup.mir_scope_exit_cleanup_validate(
        plan_result_scope.plan,
        scope_table_scope,
        resource_table_scope,
        authority_table_scope,
        ctx_scope
    );
    if cleanup_validation_scope.valid == 0 {
        fail(std.Concat("Phase 15.5 cleanup plan rejected: ", cleanup_validation_scope.reason_code));
    }
    mut resource_validation_scope := resource_mir.mir_resource_mir_table_validate(
        resource_table_scope,
        authority_table_scope,
        layout_table_scope,
        ctx_scope
    );
    if resource_validation_scope.valid == 0 {
        fail(std.Concat("Phase 15.5 resource MIR rejected: ", resource_validation_scope.reason_code));
    }
    mut cleanup_c_scope := cleanup_mir_to_c.mir_scope_exit_cleanup_to_c_source(
        plan_result_scope.plan,
        scope_table_scope,
        resource_table_scope,
        authority_table_scope,
        ctx_scope
    );
    if cleanup_c_scope.success == 0 {
        fail(std.Concat("Phase 15.5 MIR-to-C cleanup lowering rejected: ", cleanup_c_scope.reason_code));
    }

    mut request_scope := resource_mir.mir_serialize_resource_mir_for_request(resource_table_scope, authority_table_scope, layout_table_scope, ctx_scope);
    request_scope = cleanup.mir_scope_exit_cleanup_append_to_request(
        request_scope,
        scope_table_scope,
        plan_result_scope.plan,
        resource_table_scope,
        authority_table_scope,
        ctx_scope
    );
    request_scope = std.Concat(request_scope, authority.mir_serialize_resource_authority_table_for_request(authority_table_scope, layout_table_scope, ctx_scope));

    mut witness_scope := resource_mir_to_c.mir_resource_mir_to_c_witness(resource_table_scope, authority_table_scope, layout_table_scope, ctx_scope);
    witness_scope = std.Concat(witness_scope, cleanup.mir_scope_exit_cleanup_witness(plan_result_scope.plan, scope_table_scope, resource_table_scope, authority_table_scope, ctx_scope));
    witness_scope = std.Concat(witness_scope, cleanup_mir_to_c.mir_scope_exit_cleanup_lowering_witness(plan_result_scope.plan, scope_table_scope, resource_table_scope, authority_table_scope, ctx_scope));

    if os.WriteFile("/tmp/gust-phase15-scope-exit-cleanup.request", request_scope) == 0 ||
       os.WriteFile("/tmp/gust-phase15-scope-exit-cleanup.mir-to-c.witness", witness_scope) == 0
    {
        fail("Phase 15.5 scope-exit cleanup artifacts could not be written");
    }
    os.LogStr("SUCCESS: Phase 15.5 normal scope-exit cleanup parity smoke passed");
}
