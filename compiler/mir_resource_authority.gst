// Phase 15.1 compiler-owned resource and lifetime authority.
//
// This module is the sole semantic owner for request-local resource identity,
// resource state, transitions, cleanup obligations, destructor identity, close
// capability, and state joins. Canonical MIR metadata, both native backends,
// runtime-facing resource operations, and diagnostics consume these records.
// They must not infer ownership from source text, generated C, worker control
// flow, stack-slot lifetime, or emitted cleanup shape.

import "mir_layout.gst" as layout;

type MirResourceIdentity[ctx] struct {
    resource_id: str,
    value_id: str,
    resource_type_id: str,
    source_declaration_id: str,
    source_location: str,
    owning_function: str,
    owning_scope: str,
    resource_kind: str,
    destructor_id: str,
    close_capability_id: str,
    copy_policy: str,
    move_policy: str,
    cleanup_policy: str,
    target_id: str,
    target_triple: str,
    layout_id: str
}

type MirResourceState[ctx] struct {
    resource_id: str,
    program_point: str,
    state: str
}

type MirResourceTransition[ctx] struct {
    transition_id: str,
    resource_id: str,
    prior_state: str,
    operation: str,
    resulting_state: str,
    program_point: str,
    source_location: str,
    control_flow_edge: str,
    cleanup_id: str,
    diagnostic_reason_code: str
}

type MirCleanupObligation[ctx] struct {
    cleanup_id: str,
    resource_id: str,
    destructor_id: str,
    cleanup_reason: str,
    scope_exit_id: str,
    insertion_scope: str,
    execution_order: int,
    source_location: str,
    target_block: str,
    exactly_once: int,
    manual_close_policy: str,
    move_policy: str,
    early_return_policy: str,
    failure_policy: str
}

type MirDestructorIdentity[ctx] struct {
    destructor_id: str,
    resource_type_id: str,
    runtime_symbol: str,
    descriptor_id: str,
    target_id: str,
    target_triple: str
}

type MirCloseCapability[ctx] struct {
    close_capability_id: str,
    resource_type_id: str,
    runtime_symbol: str,
    suppresses_deferred_cleanup: int,
    repeated_close_policy: str,
    target_id: str,
    target_triple: str
}

type MirResourceStateJoin[ctx] struct {
    join_id: str,
    program_point: str,
    incoming_resource_ids: Index[std.Vector[str, ctx], ctx],
    incoming_states: Index[std.Vector[str, ctx], ctx],
    resulting_state: str,
    all_paths_agree: int,
    cleanup_obligation_live: int,
    valid: int,
    diagnostic_reason_code: str
}

// Associated canonical-MIR metadata. The producer records which canonical MIR
// value and operation reference each compiler-owned resource and cleanup ID.
type MirResourceMirReference[ctx] struct {
    reference_id: str,
    mir_value_id: str,
    mir_operation_id: str,
    resource_id: str,
    cleanup_id: str
}

type MirResourceAuthorityTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    semantic_authority: str,
    identity_policy: str,
    state_policy: str,
    cleanup_policy: str,
    resources: Index[std.Vector[MirResourceIdentity[ctx], ctx], ctx],
    states: Index[std.Vector[MirResourceState[ctx], ctx], ctx],
    transitions: Index[std.Vector[MirResourceTransition[ctx], ctx], ctx],
    cleanups: Index[std.Vector[MirCleanupObligation[ctx], ctx], ctx],
    destructors: Index[std.Vector[MirDestructorIdentity[ctx], ctx], ctx],
    close_capabilities: Index[std.Vector[MirCloseCapability[ctx], ctx], ctx],
    joins: Index[std.Vector[MirResourceStateJoin[ctx], ctx], ctx],
    mir_references: Index[std.Vector[MirResourceMirReference[ctx], ctx], ctx]
}

type MirResourceIdentityQuery[ctx] struct { found: int, value: MirResourceIdentity[ctx] }
type MirResourceStateQuery[ctx] struct { found: int, value: MirResourceState[ctx] }
type MirDestructorIdentityQuery[ctx] struct { found: int, value: MirDestructorIdentity[ctx] }
type MirCloseCapabilityQuery[ctx] struct { found: int, value: MirCloseCapability[ctx] }

type MirResourceTransitionValidation[ctx] struct {
    valid: int,
    resulting_state: str,
    reason_code: str
}

type MirResourceJoinResult[ctx] struct {
    valid: int,
    resulting_state: str,
    reason_code: str
}

type MirResourceTableValidation[ctx] struct {
    valid: int,
    reason_code: str
}

func mir_resource_empty_identity_vector(ctx: &Arena) Index[std.Vector[MirResourceIdentity[ctx], ctx], ctx] {
    mut values: std.Vector[MirResourceIdentity[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirResourceIdentity[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_resource_empty_state_vector(ctx: &Arena) Index[std.Vector[MirResourceState[ctx], ctx], ctx] {
    mut values: std.Vector[MirResourceState[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirResourceState[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_resource_empty_transition_vector(ctx: &Arena) Index[std.Vector[MirResourceTransition[ctx], ctx], ctx] {
    mut values: std.Vector[MirResourceTransition[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirResourceTransition[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_resource_empty_cleanup_vector(ctx: &Arena) Index[std.Vector[MirCleanupObligation[ctx], ctx], ctx] {
    mut values: std.Vector[MirCleanupObligation[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirCleanupObligation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_resource_empty_destructor_vector(ctx: &Arena) Index[std.Vector[MirDestructorIdentity[ctx], ctx], ctx] {
    mut values: std.Vector[MirDestructorIdentity[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirDestructorIdentity[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_resource_empty_close_vector(ctx: &Arena) Index[std.Vector[MirCloseCapability[ctx], ctx], ctx] {
    mut values: std.Vector[MirCloseCapability[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirCloseCapability[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_resource_empty_join_vector(ctx: &Arena) Index[std.Vector[MirResourceStateJoin[ctx], ctx], ctx] {
    mut values: std.Vector[MirResourceStateJoin[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirResourceStateJoin[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_resource_empty_reference_vector(ctx: &Arena) Index[std.Vector[MirResourceMirReference[ctx], ctx], ctx] {
    mut values: std.Vector[MirResourceMirReference[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirResourceMirReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_resource_empty_str_vector(ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut values: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_resource_push_str(target: Index[std.Vector[str, ctx], ctx], value: str, ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut values: std.Vector[str, ctx] := ctx[target];
    values.Push(std.Clone(ctx, value));
    ctx.Set(target, values);
    return target;
}

func mir_resource_field_is_safe(value: str, allow_empty: int) int {
    if allow_empty == 0 && len(value) == 0 { return 0; }
    if std.str_find(value, "\n") != 0 - 1 { return 0; }
    if std.str_find(value, "\r") != 0 - 1 { return 0; }
    return 1;
}

func mir_resource_state_name_is_valid(state: str) int {
    if std.str_eq(state, "uninitialized") == 1 { return 1; }
    if std.str_eq(state, "live") == 1 { return 1; }
    if std.str_eq(state, "moved") == 1 { return 1; }
    if std.str_eq(state, "manually_closed") == 1 { return 1; }
    if std.str_eq(state, "cleanup_scheduled") == 1 { return 1; }
    if std.str_eq(state, "destroyed") == 1 { return 1; }
    return 0;
}

func mir_resource_operation_is_valid(operation: str) int {
    if std.str_eq(operation, "initialize") == 1 { return 1; }
    if std.str_eq(operation, "move") == 1 { return 1; }
    if std.str_eq(operation, "use") == 1 { return 1; }
    if std.str_eq(operation, "assign_replacement") == 1 { return 1; }
    if std.str_eq(operation, "schedule_cleanup") == 1 { return 1; }
    if std.str_eq(operation, "manual_close") == 1 { return 1; }
    if std.str_eq(operation, "cancel_cleanup_after_manual_close") == 1 { return 1; }
    if std.str_eq(operation, "invoke_destructor") == 1 { return 1; }
    if std.str_eq(operation, "mark_destroyed") == 1 { return 1; }
    if std.str_eq(operation, "join_states") == 1 { return 1; }
    return 0;
}

// Deterministic request-local semantic identity. It is derived from compiler
// function, scope, declaration, and ordinal state. No file, registry, MIR, C,
// or Markdown digest participates in semantic identity.
func mir_resource_identity_id(function_id: str, scope_id: str, declaration_id: str, request_ordinal: int, ctx: &Arena) str {
    mut identity := "resource:v1:function=";
    identity = std.Concat(identity, function_id);
    identity = std.Concat(identity, ":scope=");
    identity = std.Concat(identity, scope_id);
    identity = std.Concat(identity, ":declaration=");
    identity = std.Concat(identity, declaration_id);
    identity = std.Concat(identity, ":ordinal=");
    identity = std.Concat(identity, std.FormatInt(request_ordinal));
    return std.Clone(ctx, identity);
}

func mir_cleanup_obligation_id(resource_id: str, scope_exit_id: str, request_ordinal: int, ctx: &Arena) str {
    mut identity := "cleanup:v1:resource=";
    identity = std.Concat(identity, resource_id);
    identity = std.Concat(identity, ":scope_exit=");
    identity = std.Concat(identity, scope_exit_id);
    identity = std.Concat(identity, ":ordinal=");
    identity = std.Concat(identity, std.FormatInt(request_ordinal));
    return std.Clone(ctx, identity);
}

func mir_resource_transition_id(resource_id: str, operation: str, program_point: str, ctx: &Arena) str {
    mut identity := "resource_transition:v1:resource=";
    identity = std.Concat(identity, resource_id);
    identity = std.Concat(identity, ":operation=");
    identity = std.Concat(identity, operation);
    identity = std.Concat(identity, ":point=");
    identity = std.Concat(identity, program_point);
    return std.Clone(ctx, identity);
}

func mir_resource_make_empty_table(target_id: str, target_triple: str, ctx: &Arena) MirResourceAuthorityTable[ctx] {
    mut table: MirResourceAuthorityTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_resource_authority_table.v1");
    table.target_id = std.Clone(ctx, target_id);
    table.target_triple = std.Clone(ctx, target_triple);
    table.semantic_authority = std.Clone(ctx, "compiler_owned_resource_and_lifetime_authority");
    table.identity_policy = std.Clone(ctx, "compiler_semantic_state_plus_request_ordinal_no_raw_hash");
    table.state_policy = std.Clone(ctx, "explicit_validated_deterministic_resource_transitions");
    table.cleanup_policy = std.Clone(ctx, "compiler_owned_exactly_once_cleanup_obligations");
    table.resources = mir_resource_empty_identity_vector(ctx);
    table.states = mir_resource_empty_state_vector(ctx);
    table.transitions = mir_resource_empty_transition_vector(ctx);
    table.cleanups = mir_resource_empty_cleanup_vector(ctx);
    table.destructors = mir_resource_empty_destructor_vector(ctx);
    table.close_capabilities = mir_resource_empty_close_vector(ctx);
    table.joins = mir_resource_empty_join_vector(ctx);
    table.mir_references = mir_resource_empty_reference_vector(ctx);
    return table;
}

func mir_resource_table_is_empty(table: MirResourceAuthorityTable[ctx], ctx: &Arena) int {
    mut resources: std.Vector[MirResourceIdentity[ctx], ctx] := ctx[table.resources];
    mut states: std.Vector[MirResourceState[ctx], ctx] := ctx[table.states];
    mut transitions: std.Vector[MirResourceTransition[ctx], ctx] := ctx[table.transitions];
    mut cleanups: std.Vector[MirCleanupObligation[ctx], ctx] := ctx[table.cleanups];
    mut destructors: std.Vector[MirDestructorIdentity[ctx], ctx] := ctx[table.destructors];
    mut closes: std.Vector[MirCloseCapability[ctx], ctx] := ctx[table.close_capabilities];
    mut joins: std.Vector[MirResourceStateJoin[ctx], ctx] := ctx[table.joins];
    mut references: std.Vector[MirResourceMirReference[ctx], ctx] := ctx[table.mir_references];
    if len(resources) == 0 && len(states) == 0 && len(transitions) == 0 &&
       len(cleanups) == 0 && len(destructors) == 0 && len(closes) == 0 &&
       len(joins) == 0 && len(references) == 0
    {
        return 1;
    }
    return 0;
}

func mir_resource_table_with_resource(table: MirResourceAuthorityTable[ctx], value: MirResourceIdentity[ctx], ctx: &Arena) MirResourceAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirResourceIdentity[ctx], ctx] := ctx[updated.resources];
    values.Push(value);
    ctx.Set(updated.resources, values);
    return updated;
}

func mir_resource_table_with_state(table: MirResourceAuthorityTable[ctx], value: MirResourceState[ctx], ctx: &Arena) MirResourceAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirResourceState[ctx], ctx] := ctx[updated.states];
    values.Push(value);
    ctx.Set(updated.states, values);
    return updated;
}

func mir_resource_table_with_transition(table: MirResourceAuthorityTable[ctx], value: MirResourceTransition[ctx], ctx: &Arena) MirResourceAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirResourceTransition[ctx], ctx] := ctx[updated.transitions];
    values.Push(value);
    ctx.Set(updated.transitions, values);
    return updated;
}

func mir_resource_table_with_cleanup(table: MirResourceAuthorityTable[ctx], value: MirCleanupObligation[ctx], ctx: &Arena) MirResourceAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirCleanupObligation[ctx], ctx] := ctx[updated.cleanups];
    values.Push(value);
    ctx.Set(updated.cleanups, values);
    return updated;
}

func mir_resource_table_with_destructor(table: MirResourceAuthorityTable[ctx], value: MirDestructorIdentity[ctx], ctx: &Arena) MirResourceAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirDestructorIdentity[ctx], ctx] := ctx[updated.destructors];
    values.Push(value);
    ctx.Set(updated.destructors, values);
    return updated;
}

func mir_resource_table_with_close_capability(table: MirResourceAuthorityTable[ctx], value: MirCloseCapability[ctx], ctx: &Arena) MirResourceAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirCloseCapability[ctx], ctx] := ctx[updated.close_capabilities];
    values.Push(value);
    ctx.Set(updated.close_capabilities, values);
    return updated;
}

func mir_resource_table_with_join(table: MirResourceAuthorityTable[ctx], value: MirResourceStateJoin[ctx], ctx: &Arena) MirResourceAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirResourceStateJoin[ctx], ctx] := ctx[updated.joins];
    values.Push(value);
    ctx.Set(updated.joins, values);
    return updated;
}

func mir_resource_table_with_mir_reference(table: MirResourceAuthorityTable[ctx], value: MirResourceMirReference[ctx], ctx: &Arena) MirResourceAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirResourceMirReference[ctx], ctx] := ctx[updated.mir_references];
    values.Push(value);
    ctx.Set(updated.mir_references, values);
    return updated;
}

// resource_of(value)
func mir_resource_of(table: MirResourceAuthorityTable[ctx], value_id: str, ctx: &Arena) MirResourceIdentityQuery[ctx] {
    mut result: MirResourceIdentityQuery[ctx];
    result.found = 0;
    mut resources: std.Vector[MirResourceIdentity[ctx], ctx] := ctx[table.resources];
    mut index := 0;
    while index < len(resources) {
        if std.str_eq(resources[index].value_id, value_id) == 1 {
            result.found = 1;
            result.value = resources[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_resource_by_id(table: MirResourceAuthorityTable[ctx], resource_id: str, ctx: &Arena) MirResourceIdentityQuery[ctx] {
    mut result: MirResourceIdentityQuery[ctx];
    result.found = 0;
    mut resources: std.Vector[MirResourceIdentity[ctx], ctx] := ctx[table.resources];
    mut index := 0;
    while index < len(resources) {
        if std.str_eq(resources[index].resource_id, resource_id) == 1 {
            result.found = 1;
            result.value = resources[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

// resource_state_at(value, program_point)
func mir_resource_state_at(table: MirResourceAuthorityTable[ctx], resource_id: str, program_point: str, ctx: &Arena) MirResourceStateQuery[ctx] {
    mut result: MirResourceStateQuery[ctx];
    result.found = 0;
    mut states: std.Vector[MirResourceState[ctx], ctx] := ctx[table.states];
    mut index := 0;
    while index < len(states) {
        if std.str_eq(states[index].resource_id, resource_id) == 1 &&
           std.str_eq(states[index].program_point, program_point) == 1
        {
            result.found = 1;
            result.value = states[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_resource_latest_state(table: MirResourceAuthorityTable[ctx], resource_id: str, ctx: &Arena) MirResourceStateQuery[ctx] {
    mut result: MirResourceStateQuery[ctx];
    result.found = 0;
    mut states: std.Vector[MirResourceState[ctx], ctx] := ctx[table.states];
    mut index := 0;
    while index < len(states) {
        if std.str_eq(states[index].resource_id, resource_id) == 1 {
            result.found = 1;
            result.value = states[index];
        }
        index = index + 1;
    }
    return result;
}

func mir_resource_transition_validation(valid: int, resulting_state: str, reason_code: str, ctx: &Arena) MirResourceTransitionValidation[ctx] {
    mut result: MirResourceTransitionValidation[ctx];
    result.valid = valid;
    result.resulting_state = std.Clone(ctx, resulting_state);
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

// validate_resource_transition(resource, operation, point)
func mir_validate_resource_transition(table: MirResourceAuthorityTable[ctx], resource_id: str, operation: str, program_point: str, ctx: &Arena) MirResourceTransitionValidation[ctx] {
    if mir_resource_by_id(table, resource_id, ctx).found == 0 {
        return mir_resource_transition_validation(0, "", "resource_unknown_id", ctx);
    }
    if mir_resource_operation_is_valid(operation) == 0 {
        return mir_resource_transition_validation(0, "", "resource_operation_unknown", ctx);
    }
    mut state_query := mir_resource_state_at(table, resource_id, program_point, ctx);
    if state_query.found == 0 {
        return mir_resource_transition_validation(0, "", "resource_state_missing_at_program_point", ctx);
    }
    mut prior := state_query.value.state;
    if std.str_eq(operation, "initialize") == 1 &&
       (std.str_eq(prior, "uninitialized") == 1 || std.str_eq(prior, "moved") == 1 || std.str_eq(prior, "destroyed") == 1)
    {
        return mir_resource_transition_validation(1, "live", "resource_transition_valid", ctx);
    }
    if std.str_eq(operation, "use") == 1 && std.str_eq(prior, "live") == 1 {
        return mir_resource_transition_validation(1, "live", "resource_transition_valid", ctx);
    }
    if std.str_eq(operation, "move") == 1 && std.str_eq(prior, "live") == 1 {
        return mir_resource_transition_validation(1, "moved", "resource_transition_valid", ctx);
    }
    if std.str_eq(operation, "schedule_cleanup") == 1 && std.str_eq(prior, "live") == 1 {
        return mir_resource_transition_validation(1, "cleanup_scheduled", "resource_transition_valid", ctx);
    }
    if std.str_eq(operation, "manual_close") == 1 && std.str_eq(prior, "live") == 1 {
        return mir_resource_transition_validation(1, "manually_closed", "resource_transition_valid", ctx);
    }
    if std.str_eq(operation, "cancel_cleanup_after_manual_close") == 1 && std.str_eq(prior, "manually_closed") == 1 {
        return mir_resource_transition_validation(1, "manually_closed", "resource_transition_valid", ctx);
    }
    if std.str_eq(operation, "invoke_destructor") == 1 && std.str_eq(prior, "cleanup_scheduled") == 1 {
        return mir_resource_transition_validation(1, "destroyed", "resource_transition_valid", ctx);
    }
    if std.str_eq(operation, "mark_destroyed") == 1 &&
       (std.str_eq(prior, "cleanup_scheduled") == 1 || std.str_eq(prior, "manually_closed") == 1)
    {
        return mir_resource_transition_validation(1, "destroyed", "resource_transition_valid", ctx);
    }
    if std.str_eq(operation, "assign_replacement") == 1 && std.str_eq(prior, "live") == 1 {
        return mir_resource_transition_validation(1, "cleanup_scheduled", "resource_transition_valid", ctx);
    }
    if std.str_eq(operation, "join_states") == 1 {
        return mir_resource_transition_validation(1, prior, "resource_transition_valid", ctx);
    }
    return mir_resource_transition_validation(0, "", "resource_impossible_state_transition", ctx);
}

// cleanup_obligations(scope_exit)
func mir_cleanup_obligations(table: MirResourceAuthorityTable[ctx], scope_exit_id: str, ctx: &Arena) Index[std.Vector[MirCleanupObligation[ctx], ctx], ctx] {
    mut result := mir_resource_empty_cleanup_vector(ctx);
    mut cleanups: std.Vector[MirCleanupObligation[ctx], ctx] := ctx[table.cleanups];
    mut selected: std.Vector[MirCleanupObligation[ctx], ctx] := ctx[result];
    mut index := 0;
    while index < len(cleanups) {
        if std.str_eq(cleanups[index].scope_exit_id, scope_exit_id) == 1 {
            selected.Push(cleanups[index]);
        }
        index = index + 1;
    }
    ctx.Set(result, selected);
    return result;
}

// destructor_for(resource_type)
func mir_destructor_for(table: MirResourceAuthorityTable[ctx], resource_type_id: str, ctx: &Arena) MirDestructorIdentityQuery[ctx] {
    mut result: MirDestructorIdentityQuery[ctx];
    result.found = 0;
    mut destructors: std.Vector[MirDestructorIdentity[ctx], ctx] := ctx[table.destructors];
    mut index := 0;
    while index < len(destructors) {
        if std.str_eq(destructors[index].resource_type_id, resource_type_id) == 1 {
            result.found = 1;
            result.value = destructors[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_close_capability_for(table: MirResourceAuthorityTable[ctx], resource_type_id: str, ctx: &Arena) MirCloseCapabilityQuery[ctx] {
    mut result: MirCloseCapabilityQuery[ctx];
    result.found = 0;
    mut capabilities: std.Vector[MirCloseCapability[ctx], ctx] := ctx[table.close_capabilities];
    mut index := 0;
    while index < len(capabilities) {
        if std.str_eq(capabilities[index].resource_type_id, resource_type_id) == 1 {
            result.found = 1;
            result.value = capabilities[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

// join_resource_states(incoming_states)
func mir_join_resource_states(incoming_states: Index[std.Vector[str, ctx], ctx], ctx: &Arena) MirResourceJoinResult[ctx] {
    mut result: MirResourceJoinResult[ctx];
    mut states: std.Vector[str, ctx] := ctx[incoming_states];
    if len(states) == 0 {
        result.valid = 0;
        result.resulting_state = std.Clone(ctx, "");
        result.reason_code = std.Clone(ctx, "resource_join_empty");
        return result;
    }
    mut first := states[0];
    if mir_resource_state_name_is_valid(first) == 0 {
        result.valid = 0;
        result.resulting_state = std.Clone(ctx, "");
        result.reason_code = std.Clone(ctx, "resource_join_unknown_state");
        return result;
    }
    mut index := 1;
    while index < len(states) {
        if std.str_eq(states[index], first) == 0 {
            result.valid = 0;
            result.resulting_state = std.Clone(ctx, "");
            result.reason_code = std.Clone(ctx, "resource_join_state_disagreement");
            return result;
        }
        index = index + 1;
    }
    result.valid = 1;
    result.resulting_state = std.Clone(ctx, first);
    result.reason_code = std.Clone(ctx, "resource_join_valid");
    return result;
}

func mir_resource_table_validation(valid: int, reason_code: str, ctx: &Arena) MirResourceTableValidation[ctx] {
    mut result: MirResourceTableValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_resource_has_destructor_id(table: MirResourceAuthorityTable[ctx], destructor_id: str, ctx: &Arena) int {
    mut destructors: std.Vector[MirDestructorIdentity[ctx], ctx] := ctx[table.destructors];
    mut index := 0;
    while index < len(destructors) {
        if std.str_eq(destructors[index].destructor_id, destructor_id) == 1 { return 1; }
        index = index + 1;
    }
    return 0;
}

func mir_resource_has_cleanup_id(table: MirResourceAuthorityTable[ctx], cleanup_id: str, ctx: &Arena) int {
    mut cleanups: std.Vector[MirCleanupObligation[ctx], ctx] := ctx[table.cleanups];
    mut index := 0;
    while index < len(cleanups) {
        if std.str_eq(cleanups[index].cleanup_id, cleanup_id) == 1 { return 1; }
        index = index + 1;
    }
    return 0;
}

func mir_resource_cleanup_has_terminal_transition(table: MirResourceAuthorityTable[ctx], cleanup_id: str, resource_id: str, ctx: &Arena) int {
    mut transitions: std.Vector[MirResourceTransition[ctx], ctx] := ctx[table.transitions];
    mut index := 0;
    while index < len(transitions) {
        if std.str_eq(transitions[index].cleanup_id, cleanup_id) == 1 &&
           std.str_eq(transitions[index].resource_id, resource_id) == 1 &&
           std.str_eq(transitions[index].operation, "invoke_destructor") == 1 &&
           std.str_eq(transitions[index].resulting_state, "destroyed") == 1
        {
            return 1;
        }
        index = index + 1;
    }
    return 0;
}

func mir_resource_has_mir_resource_reference(table: MirResourceAuthorityTable[ctx], resource_id: str, ctx: &Arena) int {
    mut references: std.Vector[MirResourceMirReference[ctx], ctx] := ctx[table.mir_references];
    mut index := 0;
    while index < len(references) {
        if std.str_eq(references[index].resource_id, resource_id) == 1 { return 1; }
        index = index + 1;
    }
    return 0;
}

func mir_resource_has_mir_cleanup_reference(table: MirResourceAuthorityTable[ctx], cleanup_id: str, ctx: &Arena) int {
    mut references: std.Vector[MirResourceMirReference[ctx], ctx] := ctx[table.mir_references];
    mut index := 0;
    while index < len(references) {
        if std.str_eq(references[index].cleanup_id, cleanup_id) == 1 { return 1; }
        index = index + 1;
    }
    return 0;
}

// Request deserialization/consistency validation. The worker may validate this
// immutable compiler-produced table, but it may not invent missing ownership
// semantics or a cleanup plan.
func mir_resource_authority_table_validate(table: MirResourceAuthorityTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) MirResourceTableValidation[ctx] {
    if std.str_eq(table.format, "gust.compiler_resource_authority_table.v1") == 0 {
        return mir_resource_table_validation(0, "resource_table_unknown_format", ctx);
    }
    if std.str_eq(table.target_id, layout_table.target.target_id) == 0 ||
       std.str_eq(table.target_triple, layout_table.target.target_triple) == 0
    {
        return mir_resource_table_validation(0, "resource_target_or_layout_mismatch", ctx);
    }
    if std.str_eq(table.semantic_authority, "compiler_owned_resource_and_lifetime_authority") == 0 ||
       std.str_eq(table.identity_policy, "compiler_semantic_state_plus_request_ordinal_no_raw_hash") == 0 ||
       std.str_eq(table.state_policy, "explicit_validated_deterministic_resource_transitions") == 0 ||
       std.str_eq(table.cleanup_policy, "compiler_owned_exactly_once_cleanup_obligations") == 0
    {
        return mir_resource_table_validation(0, "resource_authority_policy_mismatch", ctx);
    }
    if mir_resource_table_is_empty(table, ctx) == 1 {
        return mir_resource_table_validation(1, "resource_table_valid_empty", ctx);
    }

    mut resources: std.Vector[MirResourceIdentity[ctx], ctx] := ctx[table.resources];
    mut states: std.Vector[MirResourceState[ctx], ctx] := ctx[table.states];
    mut transitions: std.Vector[MirResourceTransition[ctx], ctx] := ctx[table.transitions];
    mut cleanups: std.Vector[MirCleanupObligation[ctx], ctx] := ctx[table.cleanups];
    mut destructors: std.Vector[MirDestructorIdentity[ctx], ctx] := ctx[table.destructors];
    mut closes: std.Vector[MirCloseCapability[ctx], ctx] := ctx[table.close_capabilities];
    mut joins: std.Vector[MirResourceStateJoin[ctx], ctx] := ctx[table.joins];
    mut references: std.Vector[MirResourceMirReference[ctx], ctx] := ctx[table.mir_references];

    mut index := 0;
    while index < len(resources) {
        mut resource := resources[index];
        if mir_resource_field_is_safe(resource.resource_id, 0) == 0 ||
           mir_resource_field_is_safe(resource.value_id, 0) == 0 ||
           mir_resource_field_is_safe(resource.resource_type_id, 0) == 0 ||
           mir_resource_field_is_safe(resource.source_declaration_id, 0) == 0 ||
           mir_resource_field_is_safe(resource.owning_function, 0) == 0 ||
           mir_resource_field_is_safe(resource.owning_scope, 0) == 0 ||
           mir_resource_field_is_safe(resource.destructor_id, 0) == 0
        {
            return mir_resource_table_validation(0, "resource_record_invalid", ctx);
        }
        if std.str_eq(resource.target_id, table.target_id) == 0 ||
           std.str_eq(resource.target_triple, table.target_triple) == 0
        {
            return mir_resource_table_validation(0, "resource_target_or_layout_mismatch", ctx);
        }
        if len(resource.layout_id) != 0 &&
           layout.mir_layout_table_has_layout_id(layout_table, resource.layout_id, ctx) == 0
        {
            return mir_resource_table_validation(0, "resource_target_or_layout_mismatch", ctx);
        }
        if mir_resource_has_destructor_id(table, resource.destructor_id, ctx) == 0 {
            return mir_resource_table_validation(0, "resource_unknown_destructor_id", ctx);
        }
        if mir_resource_has_mir_resource_reference(table, resource.resource_id, ctx) == 0 {
            return mir_resource_table_validation(0, "resource_metadata_inconsistent_with_canonical_mir", ctx);
        }
        mut resource_duplicate := index + 1;
        while resource_duplicate < len(resources) {
            if std.str_eq(resources[resource_duplicate].resource_id, resource.resource_id) == 1 {
                return mir_resource_table_validation(0, "resource_duplicate_conflicting_record", ctx);
            }
            resource_duplicate = resource_duplicate + 1;
        }
        index = index + 1;
    }

    index = 0;
    while index < len(destructors) {
        if mir_resource_field_is_safe(destructors[index].destructor_id, 0) == 0 ||
           mir_resource_field_is_safe(destructors[index].resource_type_id, 0) == 0 ||
           std.str_eq(destructors[index].target_id, table.target_id) == 0 ||
           std.str_eq(destructors[index].target_triple, table.target_triple) == 0
        {
            return mir_resource_table_validation(0, "resource_unknown_destructor_id", ctx);
        }
        mut destructor_duplicate := index + 1;
        while destructor_duplicate < len(destructors) {
            if std.str_eq(destructors[destructor_duplicate].destructor_id, destructors[index].destructor_id) == 1 {
                return mir_resource_table_validation(0, "resource_duplicate_destructor_id", ctx);
            }
            destructor_duplicate = destructor_duplicate + 1;
        }
        index = index + 1;
    }

    index = 0;
    while index < len(closes) {
        if mir_resource_field_is_safe(closes[index].close_capability_id, 0) == 0 ||
           std.str_eq(closes[index].target_id, table.target_id) == 0 ||
           std.str_eq(closes[index].target_triple, table.target_triple) == 0
        {
            return mir_resource_table_validation(0, "resource_unknown_close_capability_id", ctx);
        }
        index = index + 1;
    }

    index = 0;
    while index < len(states) {
        if mir_resource_by_id(table, states[index].resource_id, ctx).found == 0 {
            return mir_resource_table_validation(0, "resource_unknown_id", ctx);
        }
        if mir_resource_state_name_is_valid(states[index].state) == 0 {
            return mir_resource_table_validation(0, "resource_impossible_state_transition", ctx);
        }
        index = index + 1;
    }

    index = 0;
    while index < len(transitions) {
        mut transition := transitions[index];
        if mir_resource_by_id(table, transition.resource_id, ctx).found == 0 {
            return mir_resource_table_validation(0, "resource_unknown_id", ctx);
        }
        if mir_resource_operation_is_valid(transition.operation) == 0 ||
           mir_resource_state_name_is_valid(transition.prior_state) == 0 ||
           mir_resource_state_name_is_valid(transition.resulting_state) == 0
        {
            return mir_resource_table_validation(0, "resource_impossible_state_transition", ctx);
        }
        mut validation := mir_validate_resource_transition(
            table,
            transition.resource_id,
            transition.operation,
            transition.program_point,
            ctx
        );
        if validation.valid == 0 || std.str_eq(validation.resulting_state, transition.resulting_state) == 0 {
            return mir_resource_table_validation(0, "resource_impossible_state_transition", ctx);
        }
        if len(transition.cleanup_id) != 0 && mir_resource_has_cleanup_id(table, transition.cleanup_id, ctx) == 0 {
            return mir_resource_table_validation(0, "resource_unknown_cleanup_id", ctx);
        }
        index = index + 1;
    }

    index = 0;
    while index < len(cleanups) {
        mut cleanup := cleanups[index];
        if mir_resource_by_id(table, cleanup.resource_id, ctx).found == 0 {
            return mir_resource_table_validation(0, "resource_unknown_id", ctx);
        }
        if mir_resource_has_destructor_id(table, cleanup.destructor_id, ctx) == 0 {
            return mir_resource_table_validation(0, "resource_unknown_destructor_id", ctx);
        }
        if cleanup.exactly_once != 1 || cleanup.execution_order < 0 {
            return mir_resource_table_validation(0, "resource_cleanup_obligation_invalid", ctx);
        }
        if mir_resource_has_mir_cleanup_reference(table, cleanup.cleanup_id, ctx) == 0 {
            return mir_resource_table_validation(0, "resource_metadata_inconsistent_with_canonical_mir", ctx);
        }
        mut latest := mir_resource_latest_state(table, cleanup.resource_id, ctx);
        if latest.found == 1 && std.str_eq(latest.value.state, "moved") == 1 {
            return mir_resource_table_validation(0, "resource_cleanup_for_moved_or_destroyed_value", ctx);
        }
        if latest.found == 1 &&
           std.str_eq(latest.value.state, "destroyed") == 1 &&
           mir_resource_cleanup_has_terminal_transition(table, cleanup.cleanup_id, cleanup.resource_id, ctx) == 0
        {
            return mir_resource_table_validation(0, "resource_cleanup_for_moved_or_destroyed_value", ctx);
        }
        mut cleanup_duplicate := index + 1;
        while cleanup_duplicate < len(cleanups) {
            if std.str_eq(cleanups[cleanup_duplicate].cleanup_id, cleanup.cleanup_id) == 1 {
                return mir_resource_table_validation(0, "resource_duplicate_cleanup_id", ctx);
            }
            cleanup_duplicate = cleanup_duplicate + 1;
        }
        index = index + 1;
    }

    index = 0;
    while index < len(joins) {
        mut join_states: std.Vector[str, ctx] := ctx[joins[index].incoming_states];
        mut join_result := mir_join_resource_states(joins[index].incoming_states, ctx);
        if len(join_states) == 0 || join_result.valid != joins[index].valid {
            return mir_resource_table_validation(0, "resource_join_invalid", ctx);
        }
        if join_result.valid == 1 && std.str_eq(join_result.resulting_state, joins[index].resulting_state) == 0 {
            return mir_resource_table_validation(0, "resource_join_invalid", ctx);
        }
        index = index + 1;
    }

    index = 0;
    while index < len(references) {
        if mir_resource_field_is_safe(references[index].reference_id, 0) == 0 ||
           mir_resource_field_is_safe(references[index].mir_value_id, 1) == 0 ||
           mir_resource_field_is_safe(references[index].mir_operation_id, 1) == 0
        {
            return mir_resource_table_validation(0, "resource_metadata_inconsistent_with_canonical_mir", ctx);
        }
        if len(references[index].resource_id) != 0 &&
           mir_resource_by_id(table, references[index].resource_id, ctx).found == 0
        {
            return mir_resource_table_validation(0, "resource_unknown_id", ctx);
        }
        if len(references[index].cleanup_id) != 0 &&
           mir_resource_has_cleanup_id(table, references[index].cleanup_id, ctx) == 0
        {
            return mir_resource_table_validation(0, "resource_unknown_cleanup_id", ctx);
        }
        index = index + 1;
    }

    return mir_resource_table_validation(1, "resource_table_valid", ctx);
}

func mir_resource_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

// Immutable compiler-produced native-request resource table serialization.
func mir_serialize_resource_authority_table_for_request(table: MirResourceAuthorityTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    mut validation := mir_resource_authority_table_validate(table, layout_table, ctx);
    if validation.valid == 0 {
        mut invalid := "resource_authority_format: invalid\nresource_authority_reason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut resources: std.Vector[MirResourceIdentity[ctx], ctx] := ctx[table.resources];
    mut states: std.Vector[MirResourceState[ctx], ctx] := ctx[table.states];
    mut transitions: std.Vector[MirResourceTransition[ctx], ctx] := ctx[table.transitions];
    mut cleanups: std.Vector[MirCleanupObligation[ctx], ctx] := ctx[table.cleanups];
    mut destructors: std.Vector[MirDestructorIdentity[ctx], ctx] := ctx[table.destructors];
    mut closes: std.Vector[MirCloseCapability[ctx], ctx] := ctx[table.close_capabilities];
    mut joins: std.Vector[MirResourceStateJoin[ctx], ctx] := ctx[table.joins];
    mut references: std.Vector[MirResourceMirReference[ctx], ctx] := ctx[table.mir_references];
    mut output := "resource_authority_format: gust.compiler_resource_authority_table.v1\n";
    output = mir_resource_append_field(output, "resource_authority_target_id", table.target_id, ctx);
    output = mir_resource_append_field(output, "resource_authority_target_triple", table.target_triple, ctx);
    output = mir_resource_append_field(output, "resource_authority_resource_count", std.FormatInt(len(resources)), ctx);
    output = mir_resource_append_field(output, "resource_authority_state_count", std.FormatInt(len(states)), ctx);
    output = mir_resource_append_field(output, "resource_authority_transition_count", std.FormatInt(len(transitions)), ctx);
    output = mir_resource_append_field(output, "resource_authority_cleanup_count", std.FormatInt(len(cleanups)), ctx);
    output = mir_resource_append_field(output, "resource_authority_destructor_count", std.FormatInt(len(destructors)), ctx);
    output = mir_resource_append_field(output, "resource_authority_close_capability_count", std.FormatInt(len(closes)), ctx);
    output = mir_resource_append_field(output, "resource_authority_join_count", std.FormatInt(len(joins)), ctx);
    output = mir_resource_append_field(output, "resource_authority_mir_reference_count", std.FormatInt(len(references)), ctx);

    mut index := 0;
    while index < len(resources) {
        mut resource_row := "resource_record: id=";
        resource_row = std.Concat(resource_row, resources[index].resource_id);
        resource_row = std.Concat(resource_row, ";value=");
        resource_row = std.Concat(resource_row, resources[index].value_id);
        resource_row = std.Concat(resource_row, ";type=");
        resource_row = std.Concat(resource_row, resources[index].resource_type_id);
        resource_row = std.Concat(resource_row, ";destructor=");
        resource_row = std.Concat(resource_row, resources[index].destructor_id);
        resource_row = std.Concat(resource_row, ";close=");
        resource_row = std.Concat(resource_row, resources[index].close_capability_id);
        resource_row = std.Concat(resource_row, ";layout=");
        resource_row = std.Concat(resource_row, resources[index].layout_id);
        output = std.Concat(output, resource_row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    index = 0;
    while index < len(states) {
        mut state_row := "resource_state: resource=";
        state_row = std.Concat(state_row, states[index].resource_id);
        state_row = std.Concat(state_row, ";point=");
        state_row = std.Concat(state_row, states[index].program_point);
        state_row = std.Concat(state_row, ";state=");
        state_row = std.Concat(state_row, states[index].state);
        output = std.Concat(output, state_row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    index = 0;
    while index < len(transitions) {
        mut transition_row := "resource_transition: id=";
        transition_row = std.Concat(transition_row, transitions[index].transition_id);
        transition_row = std.Concat(transition_row, ";resource=");
        transition_row = std.Concat(transition_row, transitions[index].resource_id);
        transition_row = std.Concat(transition_row, ";prior=");
        transition_row = std.Concat(transition_row, transitions[index].prior_state);
        transition_row = std.Concat(transition_row, ";operation=");
        transition_row = std.Concat(transition_row, transitions[index].operation);
        transition_row = std.Concat(transition_row, ";result=");
        transition_row = std.Concat(transition_row, transitions[index].resulting_state);
        transition_row = std.Concat(transition_row, ";point=");
        transition_row = std.Concat(transition_row, transitions[index].program_point);
        output = std.Concat(output, transition_row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    index = 0;
    while index < len(cleanups) {
        mut cleanup_row := "cleanup_record: id=";
        cleanup_row = std.Concat(cleanup_row, cleanups[index].cleanup_id);
        cleanup_row = std.Concat(cleanup_row, ";resource=");
        cleanup_row = std.Concat(cleanup_row, cleanups[index].resource_id);
        cleanup_row = std.Concat(cleanup_row, ";destructor=");
        cleanup_row = std.Concat(cleanup_row, cleanups[index].destructor_id);
        cleanup_row = std.Concat(cleanup_row, ";scope_exit=");
        cleanup_row = std.Concat(cleanup_row, cleanups[index].scope_exit_id);
        cleanup_row = std.Concat(cleanup_row, ";order=");
        cleanup_row = std.Concat(cleanup_row, std.FormatInt(cleanups[index].execution_order));
        output = std.Concat(output, cleanup_row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    index = 0;
    while index < len(destructors) {
        mut destructor_row := "destructor_record: id=";
        destructor_row = std.Concat(destructor_row, destructors[index].destructor_id);
        destructor_row = std.Concat(destructor_row, ";type=");
        destructor_row = std.Concat(destructor_row, destructors[index].resource_type_id);
        destructor_row = std.Concat(destructor_row, ";runtime_symbol=");
        destructor_row = std.Concat(destructor_row, destructors[index].runtime_symbol);
        output = std.Concat(output, destructor_row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    index = 0;
    while index < len(closes) {
        mut close_row := "close_capability_record: id=";
        close_row = std.Concat(close_row, closes[index].close_capability_id);
        close_row = std.Concat(close_row, ";type=");
        close_row = std.Concat(close_row, closes[index].resource_type_id);
        close_row = std.Concat(close_row, ";runtime_symbol=");
        close_row = std.Concat(close_row, closes[index].runtime_symbol);
        output = std.Concat(output, close_row);
        output = std.Concat(output, "\n");
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
