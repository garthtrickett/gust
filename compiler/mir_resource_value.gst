// Phase 15.2 selected resource-bearing values in canonical MIR.
//
// This module is the canonical representation consumed by MIR-to-C and the
// Cranelift worker. Resource identity is always an explicit compiler-produced
// resource_id from mir_resource_authority.gst. Backends may select storage and
// emit machine operations, but they may not derive identity from source text,
// local names, fixture names, generated C locals, or backend reconstruction.

import "mir_layout.gst" as layout;
import "mir_resource_authority.gst" as authority;

type MirResourceOperationKind enum {
    Declare,
    Initialize,
    Read,
    Move,
    ExplicitClose,
    ScheduleCleanup,
    InvokeDestructor,
    MarkDestroyed
}

type MirResourceCarrierKind enum {
    Local,
    StackSlot,
    BranchArgument,
    LoopCarry,
    AggregateField
}

// Exactly one canonical value record owns each compiler-produced resource ID.
// Storage changes are represented by carriers, not by inventing new identities.
type MirResourceValue[ctx] struct {
    value_id: str,
    resource_id: str,
    resource_type_id: str,
    layout_id: str,
    owning_scope: str,
    source_location: str,
    current_state: str,
    destructor_id: str,
    close_capability_id: str,
    cleanup_policy: str,
    copy_policy: str
}

// A carrier preserves resource identity through selected local, stack-slot,
// branch, loop, and already-layout-supported aggregate-field placements.
type MirResourceCarrier[ctx] struct {
    carrier_id: str,
    resource_id: str,
    value_id: str,
    carrier_kind: MirResourceCarrierKind,
    storage_id: str,
    backend_symbol: str,
    owning_scope: str,
    source_location: str,
    resource_type_id: str,
    layout_id: str,
    current_state: str
}

type MirResourceOperation[ctx] struct {
    operation_id: str,
    operation_kind: MirResourceOperationKind,
    resource_id: str,
    value_id: str,
    source_carrier_id: str,
    destination_carrier_id: str,
    program_point: str,
    prior_state: str,
    resulting_state: str,
    cleanup_id: str,
    destructor_id: str,
    close_capability_id: str,
    source_location: str
}

// Every selected control-flow edge carrying a resource has an explicit state.
// An empty or unknown state is rejected rather than reconstructed by a backend.
type MirResourceFlowEdge[ctx] struct {
    edge_id: str,
    from_block: str,
    to_block: str,
    resource_id: str,
    value_id: str,
    program_point: str,
    state: str,
    is_loop_backedge: int
}

type MirResourceMirTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    semantic_authority: str,
    selected_inventory: str,
    identity_policy: str,
    copy_policy: str,
    edge_state_policy: str,
    move_state_policy: str,
    values: Index[std.Vector[MirResourceValue[ctx], ctx], ctx],
    carriers: Index[std.Vector[MirResourceCarrier[ctx], ctx], ctx],
    operations: Index[std.Vector[MirResourceOperation[ctx], ctx], ctx],
    flow_edges: Index[std.Vector[MirResourceFlowEdge[ctx], ctx], ctx]
}

type MirResourceValueQuery[ctx] struct { found: int, value: MirResourceValue[ctx] }
type MirResourceCarrierQuery[ctx] struct { found: int, value: MirResourceCarrier[ctx] }
type MirResourceOperationQuery[ctx] struct { found: int, value: MirResourceOperation[ctx] }

type MirResourceMirValidation[ctx] struct {
    valid: int,
    reason_code: str
}

type MirResourceMoveDiagnostic[ctx] struct {
    resource_id: str,
    resource_declaration: str,
    move_site: str,
    invalid_use_site: str,
    prior_state: str,
    attempted_operation: str,
    reason_code: str
}

type MirResourceMoveValidation[ctx] struct {
    valid: int,
    resulting_state: str,
    reason_code: str,
    diagnostic: MirResourceMoveDiagnostic[ctx]
}

type MirResourceStorageState[ctx] struct {
    found: int,
    state: str,
    resource_id: str,
    move_site: str
}

func mir_resource_mir_empty_value_vector(ctx: &Arena) Index[std.Vector[MirResourceValue[ctx], ctx], ctx] {
    mut values: std.Vector[MirResourceValue[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirResourceValue[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_resource_mir_empty_carrier_vector(ctx: &Arena) Index[std.Vector[MirResourceCarrier[ctx], ctx], ctx] {
    mut values: std.Vector[MirResourceCarrier[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirResourceCarrier[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_resource_mir_empty_operation_vector(ctx: &Arena) Index[std.Vector[MirResourceOperation[ctx], ctx], ctx] {
    mut values: std.Vector[MirResourceOperation[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirResourceOperation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_resource_mir_empty_edge_vector(ctx: &Arena) Index[std.Vector[MirResourceFlowEdge[ctx], ctx], ctx] {
    mut values: std.Vector[MirResourceFlowEdge[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirResourceFlowEdge[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_resource_mir_field_is_safe(value: str, allow_empty: int) int {
    if allow_empty == 0 && len(value) == 0 { return 0; }
    if std.str_find(value, "\n") != 0 - 1 { return 0; }
    if std.str_find(value, "\r") != 0 - 1 { return 0; }
    return 1;
}

func mir_resource_operation_kind_name(kind: MirResourceOperationKind) str {
    unsafe {
        if kind.tag == 0 { return "declare"; }
        if kind.tag == 1 { return "initialize"; }
        if kind.tag == 2 { return "read"; }
        if kind.tag == 3 { return "move"; }
        if kind.tag == 4 { return "explicit_close"; }
        if kind.tag == 5 { return "schedule_cleanup"; }
        if kind.tag == 6 { return "invoke_destructor"; }
        if kind.tag == 7 { return "mark_destroyed"; }
    }
    return "unknown";
}

func mir_resource_carrier_kind_name(kind: MirResourceCarrierKind) str {
    unsafe {
        if kind.tag == 0 { return "local"; }
        if kind.tag == 1 { return "stack_slot"; }
        if kind.tag == 2 { return "branch_argument"; }
        if kind.tag == 3 { return "loop_carry"; }
        if kind.tag == 4 { return "aggregate_field"; }
    }
    return "unknown";
}

func mir_resource_operation_authority_name(kind: MirResourceOperationKind) str {
    unsafe {
        if kind.tag == 1 { return "initialize"; }
        if kind.tag == 2 { return "use"; }
        if kind.tag == 3 { return "move"; }
        if kind.tag == 4 { return "manual_close"; }
        if kind.tag == 5 { return "schedule_cleanup"; }
        if kind.tag == 6 { return "invoke_destructor"; }
        if kind.tag == 7 { return "mark_destroyed"; }
    }
    return "declare";
}

func mir_resource_mir_make_empty_table(target_id: str, target_triple: str, ctx: &Arena) MirResourceMirTable[ctx] {
    mut table: MirResourceMirTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_resource_mir.v1");
    table.target_id = std.Clone(ctx, target_id);
    table.target_triple = std.Clone(ctx, target_triple);
    table.semantic_authority = std.Clone(ctx, "compiler_owned_resource_identity_and_state");
    table.selected_inventory = std.Clone(ctx, "linear_directory_native_handle_locals_stack_slots_branches_selected_loops_layout_supported_aggregate_fields");
    table.identity_policy = std.Clone(ctx, "explicit_resource_id_only_no_backend_derivation");
    table.copy_policy = std.Clone(ctx, "non_copy_resources_move_only");
    table.edge_state_policy = std.Clone(ctx, "explicit_state_on_every_selected_resource_edge");
    table.move_state_policy = std.Clone(ctx, "carrier_state_transitions_before_driver_discovery");
    table.values = mir_resource_mir_empty_value_vector(ctx);
    table.carriers = mir_resource_mir_empty_carrier_vector(ctx);
    table.operations = mir_resource_mir_empty_operation_vector(ctx);
    table.flow_edges = mir_resource_mir_empty_edge_vector(ctx);
    return table;
}

func mir_resource_mir_table_with_value(table: MirResourceMirTable[ctx], value: MirResourceValue[ctx], ctx: &Arena) MirResourceMirTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirResourceValue[ctx], ctx] := ctx[updated.values];
    values.Push(value);
    ctx.Set(updated.values, values);
    return updated;
}

func mir_resource_mir_table_with_carrier(table: MirResourceMirTable[ctx], value: MirResourceCarrier[ctx], ctx: &Arena) MirResourceMirTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirResourceCarrier[ctx], ctx] := ctx[updated.carriers];
    values.Push(value);
    ctx.Set(updated.carriers, values);
    return updated;
}

func mir_resource_mir_table_with_operation(table: MirResourceMirTable[ctx], value: MirResourceOperation[ctx], ctx: &Arena) MirResourceMirTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirResourceOperation[ctx], ctx] := ctx[updated.operations];
    values.Push(value);
    ctx.Set(updated.operations, values);
    return updated;
}

func mir_resource_mir_table_with_flow_edge(table: MirResourceMirTable[ctx], value: MirResourceFlowEdge[ctx], ctx: &Arena) MirResourceMirTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirResourceFlowEdge[ctx], ctx] := ctx[updated.flow_edges];
    values.Push(value);
    ctx.Set(updated.flow_edges, values);
    return updated;
}

func mir_resource_value_by_id(table: MirResourceMirTable[ctx], value_id: str, ctx: &Arena) MirResourceValueQuery[ctx] {
    mut result: MirResourceValueQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirResourceValue[ctx], ctx] := ctx[table.values];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].value_id, value_id) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_resource_value_by_resource_id(table: MirResourceMirTable[ctx], resource_id: str, ctx: &Arena) MirResourceValueQuery[ctx] {
    mut result: MirResourceValueQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirResourceValue[ctx], ctx] := ctx[table.values];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].resource_id, resource_id) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_resource_carrier_by_id(table: MirResourceMirTable[ctx], carrier_id: str, ctx: &Arena) MirResourceCarrierQuery[ctx] {
    mut result: MirResourceCarrierQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirResourceCarrier[ctx], ctx] := ctx[table.carriers];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].carrier_id, carrier_id) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_resource_operation_by_id(table: MirResourceMirTable[ctx], operation_id: str, ctx: &Arena) MirResourceOperationQuery[ctx] {
    mut result: MirResourceOperationQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirResourceOperation[ctx], ctx] := ctx[table.operations];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].operation_id, operation_id) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_resource_mir_validation(valid: int, reason_code: str, ctx: &Arena) MirResourceMirValidation[ctx] {
    mut result: MirResourceMirValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_resource_move_diagnostic(resource_id: str, resource_declaration: str, move_site: str, invalid_use_site: str, prior_state: str, attempted_operation: str, reason_code: str, ctx: &Arena) MirResourceMoveDiagnostic[ctx] {
    mut diagnostic: MirResourceMoveDiagnostic[ctx];
    diagnostic.resource_id = std.Clone(ctx, resource_id);
    diagnostic.resource_declaration = std.Clone(ctx, resource_declaration);
    diagnostic.move_site = std.Clone(ctx, move_site);
    diagnostic.invalid_use_site = std.Clone(ctx, invalid_use_site);
    diagnostic.prior_state = std.Clone(ctx, prior_state);
    diagnostic.attempted_operation = std.Clone(ctx, attempted_operation);
    diagnostic.reason_code = std.Clone(ctx, reason_code);
    return diagnostic;
}

func mir_resource_move_validation(valid: int, resulting_state: str, diagnostic: MirResourceMoveDiagnostic[ctx], ctx: &Arena) MirResourceMoveValidation[ctx] {
    mut result: MirResourceMoveValidation[ctx];
    result.valid = valid;
    result.resulting_state = std.Clone(ctx, resulting_state);
    result.reason_code = std.Clone(ctx, diagnostic.reason_code);
    result.diagnostic = diagnostic;
    return result;
}

func mir_resource_move_empty_diagnostic(ctx: &Arena) MirResourceMoveDiagnostic[ctx] {
    return mir_resource_move_diagnostic("", "", "", "", "", "", "resource_move_state_valid", ctx);
}

func mir_resource_move_form_name(source: MirResourceCarrierKind, destination: MirResourceCarrierKind) str {
    unsafe {
        if source.tag == 0 && destination.tag == 0 { return "local_to_local"; }
        if source.tag == 0 && destination.tag == 4 { return "local_to_aggregate_field"; }
        if source.tag == 4 && destination.tag == 0 { return "aggregate_field_to_local"; }
        if source.tag == 0 && destination.tag == 1 { return "stack_slot_transport"; }
        if source.tag == 1 && destination.tag == 0 { return "stack_slot_transport"; }
        if source.tag == 2 || destination.tag == 2 { return "branch_edge_move"; }
        if source.tag == 3 || destination.tag == 3 { return "selected_loop_carried_move"; }
    }
    return "unsupported_move_form";
}

func mir_resource_move_form_is_supported(source: MirResourceCarrierKind, destination: MirResourceCarrierKind) int {
    if std.str_eq(mir_resource_move_form_name(source, destination), "unsupported_move_form") == 1 {
        return 0;
    }
    return 1;
}

func mir_resource_carrier_state_before_operation(table: MirResourceMirTable[ctx], carrier_id: str, operation_limit: int, ctx: &Arena) str {
    mut operations: std.Vector[MirResourceOperation[ctx], ctx] := ctx[table.operations];
    mut state := "uninitialized";
    mut index := 0;
    while index < operation_limit && index < len(operations) {
        mut operation := operations[index];
        unsafe {
            if std.str_eq(operation.destination_carrier_id, carrier_id) == 1 {
                if operation.operation_kind.tag == 0 { state = "uninitialized"; }
                if operation.operation_kind.tag == 1 { state = operation.resulting_state; }
                if operation.operation_kind.tag == 3 { state = "live"; }
            }
            if std.str_eq(operation.source_carrier_id, carrier_id) == 1 {
                if operation.operation_kind.tag == 3 { state = "moved"; }
                else if operation.operation_kind.tag != 2 { state = operation.resulting_state; }
            }
        }
        index = index + 1;
    }
    return std.Clone(ctx, state);
}

func mir_resource_storage_state_before_operation(table: MirResourceMirTable[ctx], storage_id: str, operation_limit: int, ctx: &Arena) MirResourceStorageState[ctx] {
    mut result: MirResourceStorageState[ctx];
    result.found = 0;
    result.state = std.Clone(ctx, "uninitialized");
    result.resource_id = std.Clone(ctx, "");
    result.move_site = std.Clone(ctx, "");
    mut operations: std.Vector[MirResourceOperation[ctx], ctx] := ctx[table.operations];
    mut index := 0;
    while index < operation_limit && index < len(operations) {
        mut operation := operations[index];
        mut destination := mir_resource_carrier_by_id(table, operation.destination_carrier_id, ctx);
        if destination.found == 1 && std.str_eq(destination.value.storage_id, storage_id) == 1 {
            unsafe {
                if operation.operation_kind.tag == 0 {
                    result.found = 1;
                    result.state = std.Clone(ctx, "uninitialized");
                    result.resource_id = std.Clone(ctx, operation.resource_id);
                    result.move_site = std.Clone(ctx, "");
                }
                if operation.operation_kind.tag == 1 {
                    result.found = 1;
                    result.state = std.Clone(ctx, operation.resulting_state);
                    result.resource_id = std.Clone(ctx, operation.resource_id);
                    result.move_site = std.Clone(ctx, "");
                }
                if operation.operation_kind.tag == 3 {
                    result.found = 1;
                    result.state = std.Clone(ctx, "live");
                    result.resource_id = std.Clone(ctx, operation.resource_id);
                    result.move_site = std.Clone(ctx, "");
                }
            }
        }
        mut source := mir_resource_carrier_by_id(table, operation.source_carrier_id, ctx);
        if source.found == 1 && std.str_eq(source.value.storage_id, storage_id) == 1 {
            result.found = 1;
            result.resource_id = std.Clone(ctx, operation.resource_id);
            unsafe {
                if operation.operation_kind.tag == 3 {
                    result.state = std.Clone(ctx, "moved");
                    result.move_site = std.Clone(ctx, operation.source_location);
                } else if operation.operation_kind.tag != 2 {
                    result.state = std.Clone(ctx, operation.resulting_state);
                }
            }
        }
        index = index + 1;
    }
    return result;
}

func mir_resource_move_site_before_operation(table: MirResourceMirTable[ctx], carrier_id: str, operation_limit: int, ctx: &Arena) str {
    mut operations: std.Vector[MirResourceOperation[ctx], ctx] := ctx[table.operations];
    mut move_site := "";
    mut index := 0;
    while index < operation_limit && index < len(operations) {
        unsafe {
            if operations[index].operation_kind.tag == 3 &&
               std.str_eq(operations[index].source_carrier_id, carrier_id) == 1
            {
                move_site = operations[index].source_location;
            }
            if operations[index].operation_kind.tag == 1 &&
               std.str_eq(operations[index].destination_carrier_id, carrier_id) == 1
            {
                move_site = "";
            }
        }
        index = index + 1;
    }
    return std.Clone(ctx, move_site);
}

func mir_resource_move_failure(table: MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], operation: MirResourceOperation[ctx], operation_index: int, prior_state: str, attempted_operation: str, reason_code: str, ctx: &Arena) MirResourceMoveValidation[ctx] {
    mut declaration := authority.mir_resource_by_id(authority_table, operation.resource_id, ctx);
    mut declaration_location := "";
    if declaration.found == 1 { declaration_location = declaration.value.source_location; }
    mut move_site := mir_resource_move_site_before_operation(
        table,
        operation.source_carrier_id,
        operation_index,
        ctx
    );
    mut diagnostic := mir_resource_move_diagnostic(
        operation.resource_id,
        declaration_location,
        move_site,
        operation.source_location,
        prior_state,
        attempted_operation,
        reason_code,
        ctx
    );
    return mir_resource_move_validation(0, "", diagnostic, ctx);
}

func mir_resource_storage_has_moved_then_fresh_identity(table: MirResourceMirTable[ctx], storage_id: str, predecessor_resource_id: str, fresh_resource_id: str, ctx: &Arena) int {
    mut operations: std.Vector[MirResourceOperation[ctx], ctx] := ctx[table.operations];
    mut predecessor_moved := 0;
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut history_operation := operations[operation_index];
        unsafe {
            if history_operation.operation_kind.tag == 3 &&
               std.str_eq(history_operation.resource_id, predecessor_resource_id) == 1
            {
                mut history_source := mir_resource_carrier_by_id(table, history_operation.source_carrier_id, ctx);
                if history_source.found == 1 && std.str_eq(history_source.value.storage_id, storage_id) == 1 {
                    predecessor_moved = 1;
                }
            }
            if predecessor_moved == 1 && history_operation.operation_kind.tag == 1 &&
               std.str_eq(history_operation.resource_id, fresh_resource_id) == 1
            {
                mut history_destination := mir_resource_carrier_by_id(table, history_operation.destination_carrier_id, ctx);
                if history_destination.found == 1 && std.str_eq(history_destination.value.storage_id, storage_id) == 1 {
                    return 1;
                }
            }
        }
        operation_index = operation_index + 1;
    }
    return 0;
}

func mir_resource_reassignment_replacement_source_exists(table: MirResourceMirTable[ctx], resource_id: str, carrier_id: str, source_kind: str, ctx: &Arena) int {
    mut operations: std.Vector[MirResourceOperation[ctx], ctx] := ctx[table.operations];
    mut source_index := 0;
    while source_index < len(operations) {
        mut source_operation := operations[source_index];
        unsafe {
            if std.str_eq(source_operation.resource_id, resource_id) == 1 &&
               std.str_eq(source_operation.destination_carrier_id, carrier_id) == 1
            {
                if std.str_eq(source_kind, "fresh_initialize") == 1 && source_operation.operation_kind.tag == 1 {
                    return 1;
                }
                if std.str_eq(source_kind, "move") == 1 && source_operation.operation_kind.tag == 3 {
                    return 1;
                }
            }
        }
        source_index = source_index + 1;
    }
    return 0;
}

func mir_resource_reassignment_old_resolution_exists(table: MirResourceMirTable[ctx], resource_id: str, old_carrier_id: str, cleanup_id: str, resolution_policy: str, transfer_destination_carrier_id: str, ctx: &Arena) int {
    mut operations: std.Vector[MirResourceOperation[ctx], ctx] := ctx[table.operations];
    mut resolution_index := 0;
    while resolution_index < len(operations) {
        mut resolution_operation := operations[resolution_index];
        unsafe {
            if std.str_eq(resolution_operation.resource_id, resource_id) == 1 {
                if std.str_eq(resolution_policy, "immediate_destroy") == 1 &&
                   resolution_operation.operation_kind.tag == 6 &&
                   std.str_eq(resolution_operation.cleanup_id, cleanup_id) == 1 &&
                   std.str_eq(resolution_operation.resulting_state, "destroyed") == 1
                {
                    return 1;
                }
                if std.str_eq(resolution_policy, "scheduled_cleanup") == 1 &&
                   resolution_operation.operation_kind.tag == 5 &&
                   std.str_eq(resolution_operation.cleanup_id, cleanup_id) == 1 &&
                   std.str_eq(resolution_operation.resulting_state, "cleanup_scheduled") == 1
                {
                    return 1;
                }
                if std.str_eq(resolution_policy, "transfer_before_replacement") == 1 &&
                   resolution_operation.operation_kind.tag == 3 &&
                   std.str_eq(resolution_operation.source_carrier_id, old_carrier_id) == 1 &&
                   std.str_eq(resolution_operation.destination_carrier_id, transfer_destination_carrier_id) == 1
                {
                    return 1;
                }
            }
        }
        resolution_index = resolution_index + 1;
    }
    return 0;
}

func mir_resource_reassignment_control_flow_region_exists(table: MirResourceMirTable[ctx], edge_id: str, replacement_resource_id: str, require_loop_backedge: int, ctx: &Arena) int {
    mut edges: std.Vector[MirResourceFlowEdge[ctx], ctx] := ctx[table.flow_edges];
    mut edge_index := 0;
    while edge_index < len(edges) {
        if std.str_eq(edges[edge_index].edge_id, edge_id) == 1 &&
           std.str_eq(edges[edge_index].resource_id, replacement_resource_id) == 1 &&
           std.str_eq(edges[edge_index].state, "live") == 1 &&
           edges[edge_index].is_loop_backedge == require_loop_backedge
        {
            return 1;
        }
        edge_index = edge_index + 1;
    }
    return 0;
}

func mir_resource_carrier_has_operation(table: MirResourceMirTable[ctx], carrier_id: str, ctx: &Arena) int {
    mut operations: std.Vector[MirResourceOperation[ctx], ctx] := ctx[table.operations];
    mut index := 0;
    while index < len(operations) {
        if std.str_eq(operations[index].source_carrier_id, carrier_id) == 1 ||
           std.str_eq(operations[index].destination_carrier_id, carrier_id) == 1
        {
            return 1;
        }
        index = index + 1;
    }
    return 0;
}

func mir_resource_move_state_validate(table: MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) MirResourceMoveValidation[ctx] {
    mut operations: std.Vector[MirResourceOperation[ctx], ctx] := ctx[table.operations];
    mut index := 0;
    while index < len(operations) {
        mut operation := operations[index];
        mut attempted := mir_resource_operation_authority_name(operation.operation_kind);
        unsafe {
            if operation.operation_kind.tag == 0 {
                mut destination_state := mir_resource_carrier_state_before_operation(
                    table,
                    operation.destination_carrier_id,
                    index,
                    ctx
                );
                if std.str_eq(destination_state, "uninitialized") == 0 {
                    return mir_resource_move_failure(table, authority_table, operation, index, destination_state, "declare", "resource_declaration_overwrites_initialized_storage", ctx);
                }
            } else if operation.operation_kind.tag == 1 {
                mut destination_initialize := mir_resource_carrier_by_id(
                    table,
                    operation.destination_carrier_id,
                    ctx
                );
                if destination_initialize.found == 0 {
                    return mir_resource_move_failure(table, authority_table, operation, index, "uninitialized", "initialize", "resource_move_carrier_missing", ctx);
                }
                mut destination_state_initialize := mir_resource_carrier_state_before_operation(
                    table,
                    operation.destination_carrier_id,
                    index,
                    ctx
                );
                if std.str_eq(destination_state_initialize, operation.prior_state) == 0 {
                    return mir_resource_move_failure(table, authority_table, operation, index, destination_state_initialize, "initialize", "resource_reinitialization_state_mismatch", ctx);
                }
                mut initialize_transition := authority.mir_validate_resource_transition_from_state(
                    operation.resource_id,
                    destination_state_initialize,
                    "initialize",
                    ctx
                );
                if initialize_transition.valid == 0 {
                    return mir_resource_move_failure(table, authority_table, operation, index, destination_state_initialize, "initialize", initialize_transition.reason_code, ctx);
                }
                mut storage_state := mir_resource_storage_state_before_operation(
                    table,
                    destination_initialize.value.storage_id,
                    index,
                    ctx
                );
                if storage_state.found == 1 &&
                   std.str_eq(storage_state.state, "moved") == 1
                {
                    mut reinitialization := authority.mir_validate_resource_reinitialization(
                        storage_state.resource_id,
                        operation.resource_id,
                        storage_state.state,
                        ctx
                    );
                    if reinitialization.valid == 0 {
                        mut reinit_diagnostic := mir_resource_move_diagnostic(
                            operation.resource_id,
                            operation.source_location,
                            storage_state.move_site,
                            operation.source_location,
                            storage_state.state,
                            "initialize",
                            reinitialization.reason_code,
                            ctx
                        );
                        return mir_resource_move_validation(0, "", reinit_diagnostic, ctx);
                    }
                } else if storage_state.found == 1 &&
                          std.str_eq(storage_state.resource_id, operation.resource_id) == 0 &&
                          std.str_eq(storage_state.state, "uninitialized") == 0 &&
                          std.str_eq(storage_state.state, "destroyed") == 0
                {
                    return mir_resource_move_failure(table, authority_table, operation, index, storage_state.state, "initialize", "resource_reinitialize_storage_not_moved", ctx);
                }
            } else {
                mut source_state := mir_resource_carrier_state_before_operation(
                    table,
                    operation.source_carrier_id,
                    index,
                    ctx
                );
                if std.str_eq(source_state, operation.prior_state) == 0 {
                    mut mismatch_transition := authority.mir_validate_resource_transition_from_state(
                        operation.resource_id,
                        source_state,
                        attempted,
                        ctx
                    );
                    mut mismatch_reason := "resource_move_state_trace_disagreement";
                    if mismatch_transition.valid == 0 { mismatch_reason = mismatch_transition.reason_code; }
                    return mir_resource_move_failure(table, authority_table, operation, index, source_state, attempted, mismatch_reason, ctx);
                }
                mut source_transition := authority.mir_validate_resource_transition_from_state(
                    operation.resource_id,
                    source_state,
                    attempted,
                    ctx
                );
                if source_transition.valid == 0 {
                    return mir_resource_move_failure(table, authority_table, operation, index, source_state, attempted, source_transition.reason_code, ctx);
                }
                if operation.operation_kind.tag == 3 {
                    mut source_move := mir_resource_carrier_by_id(table, operation.source_carrier_id, ctx);
                    mut destination_move := mir_resource_carrier_by_id(table, operation.destination_carrier_id, ctx);
                    if source_move.found == 0 || destination_move.found == 0 {
                        return mir_resource_move_failure(table, authority_table, operation, index, source_state, "move", "resource_move_carrier_missing", ctx);
                    }
                    if mir_resource_move_form_is_supported(source_move.value.carrier_kind, destination_move.value.carrier_kind) == 0 {
                        return mir_resource_move_failure(table, authority_table, operation, index, source_state, "move", "resource_move_form_unsupported", ctx);
                    }
                    mut destination_state_move := mir_resource_carrier_state_before_operation(
                        table,
                        operation.destination_carrier_id,
                        index,
                        ctx
                    );
                    if std.str_eq(destination_state_move, "uninitialized") == 0 &&
                       std.str_eq(destination_state_move, "moved") == 0 &&
                       std.str_eq(destination_state_move, "destroyed") == 0
                    {
                        return mir_resource_move_failure(table, authority_table, operation, index, destination_state_move, "move", "resource_move_destination_not_empty", ctx);
                    }
                }
            }
        }
        index = index + 1;
    }

    mut edges: std.Vector[MirResourceFlowEdge[ctx], ctx] := ctx[table.flow_edges];
    mut left := 0;
    while left < len(edges) {
        mut right := left + 1;
        while right < len(edges) {
            if std.str_eq(edges[left].to_block, edges[right].to_block) == 1 &&
               std.str_eq(edges[left].resource_id, edges[right].resource_id) == 1 &&
               std.str_eq(edges[left].state, edges[right].state) == 0
            {
                mut join_operation: MirResourceOperation[ctx];
                unsafe { join_operation.operation_kind.tag = 3; }
                join_operation.operation_id = std.Clone(ctx, edges[right].edge_id);
                join_operation.resource_id = std.Clone(ctx, edges[right].resource_id);
                join_operation.value_id = std.Clone(ctx, edges[right].value_id);
                join_operation.source_carrier_id = "";
                join_operation.destination_carrier_id = "";
                join_operation.program_point = std.Clone(ctx, edges[right].program_point);
                join_operation.prior_state = std.Clone(ctx, edges[right].state);
                join_operation.resulting_state = "";
                join_operation.cleanup_id = "";
                join_operation.destructor_id = "";
                join_operation.close_capability_id = "";
                join_operation.source_location = std.Clone(ctx, edges[right].program_point);
                return mir_resource_move_failure(table, authority_table, join_operation, len(operations), edges[right].state, "join_states", "resource_move_join_state_inconsistent", ctx);
            }
            right = right + 1;
        }
        left = left + 1;
    }

    return mir_resource_move_validation(1, "live", mir_resource_move_empty_diagnostic(ctx), ctx);
}

func mir_resource_move_diagnostic_text(validation: MirResourceMoveValidation[ctx], ctx: &Arena) str {
    mut output := "resource_move_diagnostic: reason=";
    output = std.Concat(output, validation.reason_code);
    output = std.Concat(output, " resource=");
    output = std.Concat(output, validation.diagnostic.resource_id);
    output = std.Concat(output, " declaration=");
    output = std.Concat(output, validation.diagnostic.resource_declaration);
    output = std.Concat(output, " move_site=");
    output = std.Concat(output, validation.diagnostic.move_site);
    output = std.Concat(output, " invalid_use_site=");
    output = std.Concat(output, validation.diagnostic.invalid_use_site);
    output = std.Concat(output, " prior_state=");
    output = std.Concat(output, validation.diagnostic.prior_state);
    output = std.Concat(output, " attempted_operation=");
    output = std.Concat(output, validation.diagnostic.attempted_operation);
    output = std.Concat(output, "\n");
    return std.Clone(ctx, output);
}

func mir_resource_operation_requires_source(kind: MirResourceOperationKind) int {
    unsafe {
        if kind.tag == 2 || kind.tag == 3 || kind.tag == 4 || kind.tag == 5 || kind.tag == 6 || kind.tag == 7 {
            return 1;
        }
    }
    return 0;
}

func mir_resource_operation_requires_destination(kind: MirResourceOperationKind) int {
    unsafe {
        if kind.tag == 0 || kind.tag == 1 || kind.tag == 3 { return 1; }
    }
    return 0;
}

func mir_resource_operation_requires_cleanup(kind: MirResourceOperationKind) int {
    unsafe {
        if kind.tag == 5 || kind.tag == 6 { return 1; }
    }
    return 0;
}

func mir_resource_operation_expected_transition(operation: MirResourceOperation[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) MirResourceMirValidation[ctx] {
    unsafe {
        if operation.operation_kind.tag == 0 {
            if std.str_eq(operation.prior_state, "uninitialized") == 0 ||
               std.str_eq(operation.resulting_state, "uninitialized") == 0
            {
                return mir_resource_mir_validation(0, "resource_mir_declaration_state_invalid", ctx);
            }
            mut declaration_state := authority.mir_resource_state_at(
                authority_table,
                operation.resource_id,
                operation.program_point,
                ctx
            );
            if declaration_state.found == 0 || std.str_eq(declaration_state.value.state, "uninitialized") == 0 {
                return mir_resource_mir_validation(0, "resource_mir_state_missing_at_program_point", ctx);
            }
            return mir_resource_mir_validation(1, "resource_mir_operation_valid", ctx);
        }
    }

    mut authority_operation := mir_resource_operation_authority_name(operation.operation_kind);
    mut transition := authority.mir_validate_resource_transition(
        authority_table,
        operation.resource_id,
        authority_operation,
        operation.program_point,
        ctx
    );
    if transition.valid == 0 {
        return mir_resource_mir_validation(0, transition.reason_code, ctx);
    }
    mut state := authority.mir_resource_state_at(
        authority_table,
        operation.resource_id,
        operation.program_point,
        ctx
    );
    if state.found == 0 || std.str_eq(state.value.state, operation.prior_state) == 0 {
        return mir_resource_mir_validation(0, "resource_mir_state_missing_at_program_point", ctx);
    }
    if std.str_eq(transition.resulting_state, operation.resulting_state) == 0 {
        return mir_resource_mir_validation(0, "resource_mir_impossible_state_transition", ctx);
    }
    return mir_resource_mir_validation(1, "resource_mir_operation_valid", ctx);
}

func mir_resource_mir_table_validate(table: MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) MirResourceMirValidation[ctx] {
    if std.str_eq(table.format, "gust.compiler_resource_mir.v1") == 0 ||
       std.str_eq(table.semantic_authority, "compiler_owned_resource_identity_and_state") == 0 ||
       std.str_eq(table.identity_policy, "explicit_resource_id_only_no_backend_derivation") == 0 ||
       std.str_eq(table.copy_policy, "non_copy_resources_move_only") == 0 ||
       std.str_eq(table.edge_state_policy, "explicit_state_on_every_selected_resource_edge") == 0 ||
       std.str_eq(table.move_state_policy, "carrier_state_transitions_before_driver_discovery") == 0
    {
        return mir_resource_mir_validation(0, "resource_mir_unknown_format_or_policy", ctx);
    }
    if std.str_eq(table.target_id, authority_table.target_id) == 0 ||
       std.str_eq(table.target_triple, authority_table.target_triple) == 0 ||
       std.str_eq(table.target_id, layout_table.target.target_id) == 0 ||
       std.str_eq(table.target_triple, layout_table.target.target_triple) == 0
    {
        return mir_resource_mir_validation(0, "resource_mir_target_or_layout_mismatch", ctx);
    }
    mut authority_validation := authority.mir_resource_authority_table_validate(
        authority_table,
        layout_table,
        ctx
    );
    if authority_validation.valid == 0 {
        return mir_resource_mir_validation(0, authority_validation.reason_code, ctx);
    }

    mut values: std.Vector[MirResourceValue[ctx], ctx] := ctx[table.values];
    mut carriers: std.Vector[MirResourceCarrier[ctx], ctx] := ctx[table.carriers];
    mut operations: std.Vector[MirResourceOperation[ctx], ctx] := ctx[table.operations];
    mut edges: std.Vector[MirResourceFlowEdge[ctx], ctx] := ctx[table.flow_edges];
    mut move_validation := mir_resource_move_state_validate(table, authority_table, ctx);
    if move_validation.valid == 0 {
        return mir_resource_mir_validation(0, move_validation.reason_code, ctx);
    }
    mut index := 0;
    while index < len(values) {
        mut value := values[index];
        if mir_resource_mir_field_is_safe(value.value_id, 0) == 0 ||
           mir_resource_mir_field_is_safe(value.resource_id, 0) == 0 ||
           mir_resource_mir_field_is_safe(value.resource_type_id, 0) == 0 ||
           mir_resource_mir_field_is_safe(value.layout_id, 0) == 0 ||
           mir_resource_mir_field_is_safe(value.owning_scope, 0) == 0 ||
           mir_resource_mir_field_is_safe(value.source_location, 0) == 0 ||
           mir_resource_mir_field_is_safe(value.cleanup_policy, 0) == 0 ||
           authority.mir_resource_state_name_is_valid(value.current_state) == 0 ||
           std.str_eq(value.copy_policy, "non_copy_resource") == 0 ||
           (len(value.destructor_id) == 0 && len(value.close_capability_id) == 0)
        {
            return mir_resource_mir_validation(0, "resource_mir_value_metadata_missing", ctx);
        }
        mut identity := authority.mir_resource_by_id(authority_table, value.resource_id, ctx);
        if identity.found == 0 {
            return mir_resource_mir_validation(0, "resource_mir_value_metadata_missing", ctx);
        }
        if std.str_eq(identity.value.value_id, value.value_id) == 0 ||
           std.str_eq(identity.value.resource_type_id, value.resource_type_id) == 0 ||
           std.str_eq(identity.value.layout_id, value.layout_id) == 0 ||
           std.str_eq(identity.value.owning_scope, value.owning_scope) == 0 ||
           std.str_eq(identity.value.source_location, value.source_location) == 0 ||
           std.str_eq(identity.value.destructor_id, value.destructor_id) == 0 ||
           std.str_eq(identity.value.close_capability_id, value.close_capability_id) == 0 ||
           std.str_eq(identity.value.cleanup_policy, value.cleanup_policy) == 0
        {
            return mir_resource_mir_validation(0, "resource_mir_type_layout_identity_mismatch", ctx);
        }
        if len(value.destructor_id) != 0 {
            mut value_destructor := authority.mir_destructor_for(
                authority_table,
                value.resource_type_id,
                ctx
            );
            if value_destructor.found == 0 ||
               std.str_eq(value_destructor.value.destructor_id, value.destructor_id) == 0
            {
                return mir_resource_mir_validation(0, "resource_mir_destructor_policy_missing", ctx);
            }
        }
        if len(value.close_capability_id) != 0 {
            mut value_close := authority.mir_close_capability_for(
                authority_table,
                value.resource_type_id,
                ctx
            );
            if value_close.found == 0 ||
               std.str_eq(value_close.value.close_capability_id, value.close_capability_id) == 0
            {
                return mir_resource_mir_validation(0, "resource_mir_close_policy_missing", ctx);
            }
        }
        mut layout_query := layout.mir_layout_of(
            layout_table,
            value.resource_type_id,
            table.target_id,
            ctx
        );
        if layout_query.found == 0 || std.str_eq(layout_query.layout.layout_id, value.layout_id) == 0 {
            return mir_resource_mir_validation(0, "resource_mir_type_layout_identity_mismatch", ctx);
        }
        mut duplicate := index + 1;
        while duplicate < len(values) {
            if std.str_eq(values[duplicate].resource_id, value.resource_id) == 1 ||
               std.str_eq(values[duplicate].value_id, value.value_id) == 1
            {
                return mir_resource_mir_validation(0, "resource_mir_duplicate_resource_identity", ctx);
            }
            duplicate = duplicate + 1;
        }
        index = index + 1;
    }

    index = 0;
    while index < len(carriers) {
        mut carrier := carriers[index];
        if mir_resource_mir_field_is_safe(carrier.carrier_id, 0) == 0 ||
           mir_resource_mir_field_is_safe(carrier.storage_id, 0) == 0 ||
           mir_resource_mir_field_is_safe(carrier.backend_symbol, 0) == 0 ||
           std.str_eq(mir_resource_carrier_kind_name(carrier.carrier_kind), "unknown") == 1 ||
           authority.mir_resource_state_name_is_valid(carrier.current_state) == 0
        {
            return mir_resource_mir_validation(0, "resource_mir_carrier_metadata_missing", ctx);
        }
        mut value_query := mir_resource_value_by_id(table, carrier.value_id, ctx);
        if value_query.found == 0 ||
           std.str_eq(value_query.value.resource_id, carrier.resource_id) == 0 ||
           std.str_eq(value_query.value.resource_type_id, carrier.resource_type_id) == 0 ||
           std.str_eq(value_query.value.layout_id, carrier.layout_id) == 0 ||
           std.str_eq(value_query.value.owning_scope, carrier.owning_scope) == 0
        {
            return mir_resource_mir_validation(0, "resource_mir_carrier_identity_mismatch", ctx);
        }
        mut duplicate_carrier := index + 1;
        while duplicate_carrier < len(carriers) {
            if std.str_eq(carriers[duplicate_carrier].carrier_id, carrier.carrier_id) == 1 {
                return mir_resource_mir_validation(0, "resource_mir_duplicate_carrier_id", ctx);
            }
            duplicate_carrier = duplicate_carrier + 1;
        }
        index = index + 1;
    }

    index = 0;
    while index < len(operations) {
        mut operation := operations[index];
        if mir_resource_mir_field_is_safe(operation.operation_id, 0) == 0 ||
           mir_resource_mir_field_is_safe(operation.resource_id, 0) == 0 ||
           mir_resource_mir_field_is_safe(operation.value_id, 0) == 0 ||
           mir_resource_mir_field_is_safe(operation.program_point, 0) == 0 ||
           mir_resource_mir_field_is_safe(operation.source_location, 0) == 0 ||
           std.str_eq(mir_resource_operation_kind_name(operation.operation_kind), "unknown") == 1
        {
            return mir_resource_mir_validation(0, "resource_mir_operation_metadata_missing", ctx);
        }
        mut operation_value := mir_resource_value_by_id(table, operation.value_id, ctx);
        if operation_value.found == 0 || std.str_eq(operation_value.value.resource_id, operation.resource_id) == 0 {
            return mir_resource_mir_validation(0, "resource_mir_operation_identity_mismatch", ctx);
        }
        if mir_resource_operation_requires_source(operation.operation_kind) == 1 {
            mut source := mir_resource_carrier_by_id(table, operation.source_carrier_id, ctx);
            if source.found == 0 || std.str_eq(source.value.resource_id, operation.resource_id) == 0 {
                return mir_resource_mir_validation(0, "resource_mir_operation_source_missing", ctx);
            }
        } else if len(operation.source_carrier_id) != 0 {
            return mir_resource_mir_validation(0, "resource_mir_operation_source_invalid", ctx);
        }
        if mir_resource_operation_requires_destination(operation.operation_kind) == 1 {
            mut destination := mir_resource_carrier_by_id(table, operation.destination_carrier_id, ctx);
            if destination.found == 0 || std.str_eq(destination.value.resource_id, operation.resource_id) == 0 {
                return mir_resource_mir_validation(0, "resource_mir_operation_destination_missing", ctx);
            }
        } else if len(operation.destination_carrier_id) != 0 {
            return mir_resource_mir_validation(0, "resource_mir_operation_destination_invalid", ctx);
        }
        unsafe {
            if operation.operation_kind.tag == 3 && std.str_eq(operation.source_carrier_id, operation.destination_carrier_id) == 1 {
                return mir_resource_mir_validation(0, "resource_mir_move_requires_distinct_carriers", ctx);
            }
        }
        if mir_resource_operation_requires_cleanup(operation.operation_kind) == 1 {
            if len(operation.cleanup_id) == 0 || authority.mir_resource_has_cleanup_id(authority_table, operation.cleanup_id, ctx) == 0 {
                return mir_resource_mir_validation(0, "resource_mir_cleanup_metadata_missing", ctx);
            }
        }
        unsafe {
            if operation.operation_kind.tag == 4 && len(operation.close_capability_id) == 0 {
                return mir_resource_mir_validation(0, "resource_mir_close_policy_missing", ctx);
            }
            if operation.operation_kind.tag == 6 && len(operation.destructor_id) == 0 {
                return mir_resource_mir_validation(0, "resource_mir_destructor_policy_missing", ctx);
            }
        }
        mut transition_validation := mir_resource_operation_expected_transition(
            operation,
            authority_table,
            ctx
        );
        if transition_validation.valid == 0 {
            return transition_validation;
        }
        mut duplicate_operation := index + 1;
        while duplicate_operation < len(operations) {
            if std.str_eq(operations[duplicate_operation].operation_id, operation.operation_id) == 1 {
                return mir_resource_mir_validation(0, "resource_mir_duplicate_operation_id", ctx);
            }
            duplicate_operation = duplicate_operation + 1;
        }
        index = index + 1;
    }

    index = 0;
    while index < len(carriers) {
        mut carrier_final_state := mir_resource_carrier_state_before_operation(
            table,
            carriers[index].carrier_id,
            len(operations),
            ctx
        );
        if mir_resource_carrier_has_operation(table, carriers[index].carrier_id, ctx) == 1 &&
           std.str_eq(carrier_final_state, carriers[index].current_state) == 0
        {
            return mir_resource_mir_validation(0, "resource_move_carrier_final_state_mismatch", ctx);
        }
        index = index + 1;
    }

    index = 0;
    while index < len(values) {
        mut final_state := "";
        mut operation_index := 0;
        while operation_index < len(operations) {
            if std.str_eq(operations[operation_index].resource_id, values[index].resource_id) == 1 {
                final_state = operations[operation_index].resulting_state;
            }
            operation_index = operation_index + 1;
        }
        if len(final_state) == 0 || std.str_eq(final_state, values[index].current_state) == 0 {
            return mir_resource_mir_validation(0, "resource_mir_current_state_mismatch", ctx);
        }
        index = index + 1;
    }

    index = 0;
    while index < len(edges) {
        mut edge := edges[index];
        if mir_resource_mir_field_is_safe(edge.edge_id, 0) == 0 ||
           mir_resource_mir_field_is_safe(edge.from_block, 0) == 0 ||
           mir_resource_mir_field_is_safe(edge.to_block, 0) == 0 ||
           mir_resource_mir_field_is_safe(edge.resource_id, 0) == 0 ||
           mir_resource_mir_field_is_safe(edge.value_id, 0) == 0 ||
           mir_resource_mir_field_is_safe(edge.program_point, 0) == 0 ||
           authority.mir_resource_state_name_is_valid(edge.state) == 0
        {
            return mir_resource_mir_validation(0, "resource_mir_state_missing_at_control_flow_edge", ctx);
        }
        mut edge_value := mir_resource_value_by_id(table, edge.value_id, ctx);
        if edge_value.found == 0 || std.str_eq(edge_value.value.resource_id, edge.resource_id) == 0 {
            return mir_resource_mir_validation(0, "resource_mir_edge_identity_mismatch", ctx);
        }
        mut edge_state := authority.mir_resource_state_at(
            authority_table,
            edge.resource_id,
            edge.program_point,
            ctx
        );
        if edge_state.found == 0 || std.str_eq(edge_state.value.state, edge.state) == 0 {
            return mir_resource_mir_validation(0, "resource_mir_state_missing_at_control_flow_edge", ctx);
        }
        mut duplicate_edge := index + 1;
        while duplicate_edge < len(edges) {
            if std.str_eq(edges[duplicate_edge].edge_id, edge.edge_id) == 1 &&
               std.str_eq(edges[duplicate_edge].resource_id, edge.resource_id) == 1
            {
                return mir_resource_mir_validation(0, "resource_mir_duplicate_edge_state", ctx);
            }
            duplicate_edge = duplicate_edge + 1;
        }
        index = index + 1;
    }

    return mir_resource_mir_validation(1, "resource_mir_table_valid", ctx);
}

func mir_resource_mir_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_serialize_resource_mir_for_request(table: MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    mut validation := mir_resource_mir_table_validate(table, authority_table, layout_table, ctx);
    if validation.valid == 0 {
        mut invalid := "resource_mir_format: invalid\nresource_mir_reason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut values: std.Vector[MirResourceValue[ctx], ctx] := ctx[table.values];
    mut carriers: std.Vector[MirResourceCarrier[ctx], ctx] := ctx[table.carriers];
    mut operations: std.Vector[MirResourceOperation[ctx], ctx] := ctx[table.operations];
    mut edges: std.Vector[MirResourceFlowEdge[ctx], ctx] := ctx[table.flow_edges];
    mut output := "resource_mir_format: gust.compiler_resource_mir.v1\n";
    output = mir_resource_mir_append_field(output, "resource_mir_target_id", table.target_id, ctx);
    output = mir_resource_mir_append_field(output, "resource_mir_target_triple", table.target_triple, ctx);
    output = mir_resource_mir_append_field(output, "resource_mir_semantic_authority", table.semantic_authority, ctx);
    output = mir_resource_mir_append_field(output, "resource_mir_selected_inventory", table.selected_inventory, ctx);
    output = mir_resource_mir_append_field(output, "resource_mir_identity_policy", table.identity_policy, ctx);
    output = mir_resource_mir_append_field(output, "resource_mir_copy_policy", table.copy_policy, ctx);
    output = mir_resource_mir_append_field(output, "resource_mir_edge_state_policy", table.edge_state_policy, ctx);
    output = mir_resource_mir_append_field(output, "resource_mir_move_state_policy", table.move_state_policy, ctx);
    output = mir_resource_mir_append_field(output, "resource_mir_value_count", std.FormatInt(len(values)), ctx);
    output = mir_resource_mir_append_field(output, "resource_mir_carrier_count", std.FormatInt(len(carriers)), ctx);
    output = mir_resource_mir_append_field(output, "resource_mir_operation_count", std.FormatInt(len(operations)), ctx);
    output = mir_resource_mir_append_field(output, "resource_mir_edge_count", std.FormatInt(len(edges)), ctx);

    mut index := 0;
    while index < len(values) {
        mut value_prefix := std.Concat("resource_mir_value_", std.FormatInt(index));
        output = mir_resource_mir_append_field(output, std.Concat(value_prefix, "_value_id"), values[index].value_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(value_prefix, "_resource_id"), values[index].resource_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(value_prefix, "_resource_type_id"), values[index].resource_type_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(value_prefix, "_layout_id"), values[index].layout_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(value_prefix, "_owning_scope"), values[index].owning_scope, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(value_prefix, "_source_location"), values[index].source_location, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(value_prefix, "_current_state"), values[index].current_state, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(value_prefix, "_destructor_id"), values[index].destructor_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(value_prefix, "_close_capability_id"), values[index].close_capability_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(value_prefix, "_cleanup_policy"), values[index].cleanup_policy, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(value_prefix, "_copy_policy"), values[index].copy_policy, ctx);
        index = index + 1;
    }

    index = 0;
    while index < len(carriers) {
        mut carrier_prefix := std.Concat("resource_mir_carrier_", std.FormatInt(index));
        output = mir_resource_mir_append_field(output, std.Concat(carrier_prefix, "_carrier_id"), carriers[index].carrier_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(carrier_prefix, "_resource_id"), carriers[index].resource_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(carrier_prefix, "_value_id"), carriers[index].value_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(carrier_prefix, "_kind"), mir_resource_carrier_kind_name(carriers[index].carrier_kind), ctx);
        output = mir_resource_mir_append_field(output, std.Concat(carrier_prefix, "_storage_id"), carriers[index].storage_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(carrier_prefix, "_backend_symbol"), carriers[index].backend_symbol, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(carrier_prefix, "_owning_scope"), carriers[index].owning_scope, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(carrier_prefix, "_source_location"), carriers[index].source_location, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(carrier_prefix, "_resource_type_id"), carriers[index].resource_type_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(carrier_prefix, "_layout_id"), carriers[index].layout_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(carrier_prefix, "_current_state"), carriers[index].current_state, ctx);
        index = index + 1;
    }

    index = 0;
    while index < len(operations) {
        mut operation_prefix := std.Concat("resource_mir_operation_", std.FormatInt(index));
        output = mir_resource_mir_append_field(output, std.Concat(operation_prefix, "_operation_id"), operations[index].operation_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(operation_prefix, "_kind"), mir_resource_operation_kind_name(operations[index].operation_kind), ctx);
        output = mir_resource_mir_append_field(output, std.Concat(operation_prefix, "_resource_id"), operations[index].resource_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(operation_prefix, "_value_id"), operations[index].value_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(operation_prefix, "_source_carrier_id"), operations[index].source_carrier_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(operation_prefix, "_destination_carrier_id"), operations[index].destination_carrier_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(operation_prefix, "_program_point"), operations[index].program_point, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(operation_prefix, "_prior_state"), operations[index].prior_state, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(operation_prefix, "_resulting_state"), operations[index].resulting_state, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(operation_prefix, "_cleanup_id"), operations[index].cleanup_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(operation_prefix, "_destructor_id"), operations[index].destructor_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(operation_prefix, "_close_capability_id"), operations[index].close_capability_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(operation_prefix, "_source_location"), operations[index].source_location, ctx);
        index = index + 1;
    }

    index = 0;
    while index < len(edges) {
        mut edge_prefix := std.Concat("resource_mir_edge_", std.FormatInt(index));
        output = mir_resource_mir_append_field(output, std.Concat(edge_prefix, "_edge_id"), edges[index].edge_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(edge_prefix, "_from_block"), edges[index].from_block, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(edge_prefix, "_to_block"), edges[index].to_block, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(edge_prefix, "_resource_id"), edges[index].resource_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(edge_prefix, "_value_id"), edges[index].value_id, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(edge_prefix, "_program_point"), edges[index].program_point, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(edge_prefix, "_state"), edges[index].state, ctx);
        output = mir_resource_mir_append_field(output, std.Concat(edge_prefix, "_is_loop_backedge"), std.FormatInt(edges[index].is_loop_backedge), ctx);
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_resource_mir_witness(table: MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    mut validation := mir_resource_mir_table_validate(table, authority_table, layout_table, ctx);
    if validation.valid == 0 {
        mut invalid := "resource_mir_witness: rejected reason=";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut values: std.Vector[MirResourceValue[ctx], ctx] := ctx[table.values];
    mut carriers: std.Vector[MirResourceCarrier[ctx], ctx] := ctx[table.carriers];
    mut operations: std.Vector[MirResourceOperation[ctx], ctx] := ctx[table.operations];
    mut edges: std.Vector[MirResourceFlowEdge[ctx], ctx] := ctx[table.flow_edges];
    mut output := "resource_mir_witness: accepted\n";
    mut index := 0;
    while index < len(values) {
        mut value_row := "resource_value: value=";
        value_row = std.Concat(value_row, values[index].value_id);
        value_row = std.Concat(value_row, " resource=");
        value_row = std.Concat(value_row, values[index].resource_id);
        value_row = std.Concat(value_row, " type=");
        value_row = std.Concat(value_row, values[index].resource_type_id);
        value_row = std.Concat(value_row, " layout=");
        value_row = std.Concat(value_row, values[index].layout_id);
        value_row = std.Concat(value_row, " scope=");
        value_row = std.Concat(value_row, values[index].owning_scope);
        value_row = std.Concat(value_row, " state=");
        value_row = std.Concat(value_row, values[index].current_state);
        output = std.Concat(output, value_row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    index = 0;
    while index < len(carriers) {
        mut carrier_row := "resource_carrier: id=";
        carrier_row = std.Concat(carrier_row, carriers[index].carrier_id);
        carrier_row = std.Concat(carrier_row, " kind=");
        carrier_row = std.Concat(carrier_row, mir_resource_carrier_kind_name(carriers[index].carrier_kind));
        carrier_row = std.Concat(carrier_row, " resource=");
        carrier_row = std.Concat(carrier_row, carriers[index].resource_id);
        carrier_row = std.Concat(carrier_row, " storage=");
        carrier_row = std.Concat(carrier_row, carriers[index].storage_id);
        carrier_row = std.Concat(carrier_row, " state=");
        carrier_row = std.Concat(carrier_row, carriers[index].current_state);
        output = std.Concat(output, carrier_row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    index = 0;
    while index < len(operations) {
        mut operation_row := "resource_operation: id=";
        operation_row = std.Concat(operation_row, operations[index].operation_id);
        operation_row = std.Concat(operation_row, " kind=");
        operation_row = std.Concat(operation_row, mir_resource_operation_kind_name(operations[index].operation_kind));
        operation_row = std.Concat(operation_row, " resource=");
        operation_row = std.Concat(operation_row, operations[index].resource_id);
        operation_row = std.Concat(operation_row, " source=");
        operation_row = std.Concat(operation_row, operations[index].source_carrier_id);
        operation_row = std.Concat(operation_row, " destination=");
        operation_row = std.Concat(operation_row, operations[index].destination_carrier_id);
        operation_row = std.Concat(operation_row, " prior=");
        operation_row = std.Concat(operation_row, operations[index].prior_state);
        operation_row = std.Concat(operation_row, " result=");
        operation_row = std.Concat(operation_row, operations[index].resulting_state);
        output = std.Concat(output, operation_row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    index = 0;
    while index < len(edges) {
        mut edge_row := "resource_edge: id=";
        edge_row = std.Concat(edge_row, edges[index].edge_id);
        edge_row = std.Concat(edge_row, " from=");
        edge_row = std.Concat(edge_row, edges[index].from_block);
        edge_row = std.Concat(edge_row, " to=");
        edge_row = std.Concat(edge_row, edges[index].to_block);
        edge_row = std.Concat(edge_row, " resource=");
        edge_row = std.Concat(edge_row, edges[index].resource_id);
        edge_row = std.Concat(edge_row, " state=");
        edge_row = std.Concat(edge_row, edges[index].state);
        edge_row = std.Concat(edge_row, " loop_backedge=");
        edge_row = std.Concat(edge_row, std.FormatInt(edges[index].is_loop_backedge));
        output = std.Concat(output, edge_row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
