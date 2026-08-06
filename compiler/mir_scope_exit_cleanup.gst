// Patch 15.5 compiler-owned cleanup insertion at ordinary lexical scope exits.
//
// The compiler records scope identity, parentage, declaration order, and the
// pre-exit resource state. Planning selects only live resources and freezes
// reverse declaration order. The resulting schedule and destructor operations
// are explicit canonical MIR; backends consume the plan mechanically.

import "mir_resource_authority.gst" as authority;
import "mir_resource_value.gst" as resource_mir;

type MirResourceScope[ctx] struct {
    scope_id: str,
    parent_scope_id: str,
    scope_kind: str,
    source_location: str,
    scope_exit_id: str,
    exit_program_point: str,
    depth: int,
    exit_sequence: int,
    selected: int
}

type MirResourceScopeBinding[ctx] struct {
    scope_id: str,
    resource_id: str,
    value_id: str,
    carrier_id: str,
    declaration_id: str,
    declaration_order: int,
    source_location: str
}

type MirResourceScopeTable[ctx] struct {
    format: str,
    semantic_authority: str,
    parent_policy: str,
    selected_scope_kinds: str,
    scopes: Index[std.Vector[MirResourceScope[ctx], ctx], ctx],
    bindings: Index[std.Vector[MirResourceScopeBinding[ctx], ctx], ctx]
}

type MirScopeExitCleanup[ctx] struct {
    schedule_operation_id: str,
    cleanup_operation_id: str,
    scope_id: str,
    parent_scope_id: str,
    resource_id: str,
    value_id: str,
    carrier_id: str,
    cleanup_obligation_id: str,
    destructor_id: str,
    owning_declaration: str,
    source_location: str,
    scope_exit_id: str,
    exit_program_point: str,
    declaration_order: int,
    execution_order: int,
    prior_state: str,
    resulting_state: str,
    observable_effect: str
}

type MirScopeExitCleanupExclusion[ctx] struct {
    scope_id: str,
    resource_id: str,
    value_id: str,
    carrier_id: str,
    state: str,
    reason: str,
    declaration_order: int,
    source_location: str
}

type MirScopeExitCleanupPlan[ctx] struct {
    format: str,
    semantic_authority: str,
    order_policy: str,
    selected_exit_kinds: str,
    entries: Index[std.Vector[MirScopeExitCleanup[ctx], ctx], ctx],
    exclusions: Index[std.Vector[MirScopeExitCleanupExclusion[ctx], ctx], ctx]
}

type MirScopeExitCleanupValidation[ctx] struct {
    valid: int,
    reason_code: str
}

type MirScopeExitCleanupPlanResult[ctx] struct {
    valid: int,
    reason_code: str,
    plan: MirScopeExitCleanupPlan[ctx]
}

func mir_scope_exit_cleanup_empty_scope_vector(ctx: &Arena) Index[std.Vector[MirResourceScope[ctx], ctx], ctx] {
    mut values_scope: std.Vector[MirResourceScope[ctx], ctx] := std.VectorNew(ctx);
    mut index_scope: Index[std.Vector[MirResourceScope[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index_scope, values_scope);
    return index_scope;
}

func mir_scope_exit_cleanup_empty_binding_vector(ctx: &Arena) Index[std.Vector[MirResourceScopeBinding[ctx], ctx], ctx] {
    mut values_binding: std.Vector[MirResourceScopeBinding[ctx], ctx] := std.VectorNew(ctx);
    mut index_binding: Index[std.Vector[MirResourceScopeBinding[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index_binding, values_binding);
    return index_binding;
}

func mir_scope_exit_cleanup_empty_entry_vector(ctx: &Arena) Index[std.Vector[MirScopeExitCleanup[ctx], ctx], ctx] {
    mut values_entry: std.Vector[MirScopeExitCleanup[ctx], ctx] := std.VectorNew(ctx);
    mut index_entry: Index[std.Vector[MirScopeExitCleanup[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index_entry, values_entry);
    return index_entry;
}

func mir_scope_exit_cleanup_empty_exclusion_vector(ctx: &Arena) Index[std.Vector[MirScopeExitCleanupExclusion[ctx], ctx], ctx] {
    mut values_exclusion: std.Vector[MirScopeExitCleanupExclusion[ctx], ctx] := std.VectorNew(ctx);
    mut index_exclusion: Index[std.Vector[MirScopeExitCleanupExclusion[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index_exclusion, values_exclusion);
    return index_exclusion;
}

func mir_scope_exit_cleanup_make_scope_table(ctx: &Arena) MirResourceScopeTable[ctx] {
    mut table_scope: MirResourceScopeTable[ctx];
    table_scope.format = std.Clone(ctx, "gust.compiler_resource_scope_table.v1");
    table_scope.semantic_authority = std.Clone(ctx, "compiler_owned_lexical_scope_identity");
    table_scope.parent_policy = std.Clone(ctx, "explicit_parent_and_depth");
    table_scope.selected_scope_kinds = std.Clone(ctx, "block_scope,function_body,selected_nested_scope");
    table_scope.scopes = mir_scope_exit_cleanup_empty_scope_vector(ctx);
    table_scope.bindings = mir_scope_exit_cleanup_empty_binding_vector(ctx);
    return table_scope;
}

func mir_scope_exit_cleanup_make_empty_plan(ctx: &Arena) MirScopeExitCleanupPlan[ctx] {
    mut plan_empty: MirScopeExitCleanupPlan[ctx];
    plan_empty.format = std.Clone(ctx, "gust.compiler_scope_exit_cleanup.v1");
    plan_empty.semantic_authority = std.Clone(ctx, "compiler_owned_cleanup_insertion");
    plan_empty.order_policy = std.Clone(ctx, "selected_scopes_by_exit_sequence_then_reverse_declaration_order");
    plan_empty.selected_exit_kinds = std.Clone(ctx, "block_scope,function_body,selected_nested_scope");
    plan_empty.entries = mir_scope_exit_cleanup_empty_entry_vector(ctx);
    plan_empty.exclusions = mir_scope_exit_cleanup_empty_exclusion_vector(ctx);
    return plan_empty;
}

func mir_scope_exit_cleanup_table_with_scope(table: MirResourceScopeTable[ctx], scope: MirResourceScope[ctx], ctx: &Arena) MirResourceScopeTable[ctx] {
    mut updated_scope_table := table;
    mut values_scope_push: std.Vector[MirResourceScope[ctx], ctx] := ctx[updated_scope_table.scopes];
    values_scope_push.Push(scope);
    ctx.Set(updated_scope_table.scopes, values_scope_push);
    return updated_scope_table;
}

func mir_scope_exit_cleanup_table_with_binding(table: MirResourceScopeTable[ctx], binding: MirResourceScopeBinding[ctx], ctx: &Arena) MirResourceScopeTable[ctx] {
    mut updated_binding_table := table;
    mut values_binding_push: std.Vector[MirResourceScopeBinding[ctx], ctx] := ctx[updated_binding_table.bindings];
    values_binding_push.Push(binding);
    ctx.Set(updated_binding_table.bindings, values_binding_push);
    return updated_binding_table;
}

func mir_scope_exit_cleanup_plan_with_entry(plan: MirScopeExitCleanupPlan[ctx], entry: MirScopeExitCleanup[ctx], ctx: &Arena) MirScopeExitCleanupPlan[ctx] {
    mut updated_entry_plan := plan;
    mut values_entry_push: std.Vector[MirScopeExitCleanup[ctx], ctx] := ctx[updated_entry_plan.entries];
    values_entry_push.Push(entry);
    ctx.Set(updated_entry_plan.entries, values_entry_push);
    return updated_entry_plan;
}

func mir_scope_exit_cleanup_plan_with_exclusion(plan: MirScopeExitCleanupPlan[ctx], exclusion: MirScopeExitCleanupExclusion[ctx], ctx: &Arena) MirScopeExitCleanupPlan[ctx] {
    mut updated_exclusion_plan := plan;
    mut values_exclusion_push: std.Vector[MirScopeExitCleanupExclusion[ctx], ctx] := ctx[updated_exclusion_plan.exclusions];
    values_exclusion_push.Push(exclusion);
    ctx.Set(updated_exclusion_plan.exclusions, values_exclusion_push);
    return updated_exclusion_plan;
}

func mir_scope_exit_cleanup_scope_count(table: MirResourceScopeTable[ctx], ctx: &Arena) int {
    mut values_scope_count: std.Vector[MirResourceScope[ctx], ctx] := ctx[table.scopes];
    return len(values_scope_count);
}

func mir_scope_exit_cleanup_scope_at(table: MirResourceScopeTable[ctx], scope_index: int, ctx: &Arena) MirResourceScope[ctx] {
    mut values_scope_at: std.Vector[MirResourceScope[ctx], ctx] := ctx[table.scopes];
    return values_scope_at[scope_index];
}

func mir_scope_exit_cleanup_binding_count(table: MirResourceScopeTable[ctx], ctx: &Arena) int {
    mut values_binding_count: std.Vector[MirResourceScopeBinding[ctx], ctx] := ctx[table.bindings];
    return len(values_binding_count);
}

func mir_scope_exit_cleanup_binding_at(table: MirResourceScopeTable[ctx], binding_index: int, ctx: &Arena) MirResourceScopeBinding[ctx] {
    mut values_binding_at: std.Vector[MirResourceScopeBinding[ctx], ctx] := ctx[table.bindings];
    return values_binding_at[binding_index];
}

func mir_scope_exit_cleanup_entry_count(plan: MirScopeExitCleanupPlan[ctx], ctx: &Arena) int {
    mut values_entry_count: std.Vector[MirScopeExitCleanup[ctx], ctx] := ctx[plan.entries];
    return len(values_entry_count);
}

func mir_scope_exit_cleanup_entry_at(plan: MirScopeExitCleanupPlan[ctx], entry_index: int, ctx: &Arena) MirScopeExitCleanup[ctx] {
    mut values_entry_at: std.Vector[MirScopeExitCleanup[ctx], ctx] := ctx[plan.entries];
    return values_entry_at[entry_index];
}

func mir_scope_exit_cleanup_exclusion_count(plan: MirScopeExitCleanupPlan[ctx], ctx: &Arena) int {
    mut values_exclusion_count: std.Vector[MirScopeExitCleanupExclusion[ctx], ctx] := ctx[plan.exclusions];
    return len(values_exclusion_count);
}

func mir_scope_exit_cleanup_exclusion_at(plan: MirScopeExitCleanupPlan[ctx], exclusion_index: int, ctx: &Arena) MirScopeExitCleanupExclusion[ctx] {
    mut values_exclusion_at: std.Vector[MirScopeExitCleanupExclusion[ctx], ctx] := ctx[plan.exclusions];
    return values_exclusion_at[exclusion_index];
}

func mir_scope_exit_cleanup_validation(valid: int, reason_code: str, ctx: &Arena) MirScopeExitCleanupValidation[ctx] {
    mut validation_result: MirScopeExitCleanupValidation[ctx];
    validation_result.valid = valid;
    validation_result.reason_code = std.Clone(ctx, reason_code);
    return validation_result;
}

func mir_scope_exit_cleanup_plan_result(valid: int, reason_code: str, plan: MirScopeExitCleanupPlan[ctx], ctx: &Arena) MirScopeExitCleanupPlanResult[ctx] {
    mut plan_result: MirScopeExitCleanupPlanResult[ctx];
    plan_result.valid = valid;
    plan_result.reason_code = std.Clone(ctx, reason_code);
    plan_result.plan = plan;
    return plan_result;
}

func mir_scope_exit_cleanup_field_is_safe(value: str, allow_empty: int) int {
    if allow_empty == 0 && len(value) == 0 { return 0; }
    if std.str_find(value, "\n") != 0 - 1 { return 0; }
    if std.str_find(value, "\r") != 0 - 1 { return 0; }
    return 1;
}

func mir_scope_exit_cleanup_scope_kind_selected(scope_kind: str) int {
    if std.str_eq(scope_kind, "block_scope") == 1 { return 1; }
    if std.str_eq(scope_kind, "function_body") == 1 { return 1; }
    if std.str_eq(scope_kind, "selected_nested_scope") == 1 { return 1; }
    return 0;
}

func mir_scope_exit_cleanup_exclusion_reason(state: str) str {
    if std.str_eq(state, "moved") == 1 { return "moved_resource"; }
    if std.str_eq(state, "manually_closed") == 1 { return "manually_closed_resource"; }
    if std.str_eq(state, "destroyed") == 1 { return "already_destroyed_resource"; }
    if std.str_eq(state, "cleanup_scheduled") == 1 { return "already_scheduled_resource"; }
    return "invalid_non_live_state";
}

func mir_scope_exit_cleanup_scope_by_id(table: MirResourceScopeTable[ctx], scope_id: str, ctx: &Arena) MirResourceScope[ctx] {
    mut scopes_by_id: std.Vector[MirResourceScope[ctx], ctx] := ctx[table.scopes];
    mut scope_by_id_index := 0;
    while scope_by_id_index < len(scopes_by_id) {
        if std.str_eq(scopes_by_id[scope_by_id_index].scope_id, scope_id) == 1 {
            return scopes_by_id[scope_by_id_index];
        }
        scope_by_id_index = scope_by_id_index + 1;
    }
    mut missing_scope: MirResourceScope[ctx];
    missing_scope.scope_id = std.Clone(ctx, "");
    return missing_scope;
}

func mir_scope_exit_cleanup_scope_for_sequence(table: MirResourceScopeTable[ctx], exit_sequence: int, ctx: &Arena) MirResourceScope[ctx] {
    mut scopes_by_sequence: std.Vector[MirResourceScope[ctx], ctx] := ctx[table.scopes];
    mut scope_sequence_index := 0;
    while scope_sequence_index < len(scopes_by_sequence) {
        if scopes_by_sequence[scope_sequence_index].selected == 1 &&
           scopes_by_sequence[scope_sequence_index].exit_sequence == exit_sequence
        {
            return scopes_by_sequence[scope_sequence_index];
        }
        scope_sequence_index = scope_sequence_index + 1;
    }
    mut missing_sequence_scope: MirResourceScope[ctx];
    missing_sequence_scope.scope_id = std.Clone(ctx, "");
    return missing_sequence_scope;
}

func mir_scope_exit_cleanup_binding_for_order(table: MirResourceScopeTable[ctx], scope_id: str, declaration_order: int, ctx: &Arena) MirResourceScopeBinding[ctx] {
    mut bindings_for_order: std.Vector[MirResourceScopeBinding[ctx], ctx] := ctx[table.bindings];
    mut binding_order_index := 0;
    while binding_order_index < len(bindings_for_order) {
        if std.str_eq(bindings_for_order[binding_order_index].scope_id, scope_id) == 1 &&
           bindings_for_order[binding_order_index].declaration_order == declaration_order
        {
            return bindings_for_order[binding_order_index];
        }
        binding_order_index = binding_order_index + 1;
    }
    mut missing_order_binding: MirResourceScopeBinding[ctx];
    missing_order_binding.scope_id = std.Clone(ctx, "");
    return missing_order_binding;
}

func mir_scope_exit_cleanup_max_declaration_order(table: MirResourceScopeTable[ctx], scope_id: str, ctx: &Arena) int {
    mut bindings_max_order: std.Vector[MirResourceScopeBinding[ctx], ctx] := ctx[table.bindings];
    mut max_declaration_order := 0;
    mut binding_max_index := 0;
    while binding_max_index < len(bindings_max_order) {
        if std.str_eq(bindings_max_order[binding_max_index].scope_id, scope_id) == 1 &&
           bindings_max_order[binding_max_index].declaration_order > max_declaration_order
        {
            max_declaration_order = bindings_max_order[binding_max_index].declaration_order;
        }
        binding_max_index = binding_max_index + 1;
    }
    return max_declaration_order;
}

func mir_scope_exit_cleanup_scope_table_validate(table: MirResourceScopeTable[ctx], ctx: &Arena) MirScopeExitCleanupValidation[ctx] {
    if std.str_eq(table.format, "gust.compiler_resource_scope_table.v1") == 0 ||
       std.str_eq(table.semantic_authority, "compiler_owned_lexical_scope_identity") == 0 ||
       std.str_eq(table.parent_policy, "explicit_parent_and_depth") == 0
    {
        return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_unknown_format", ctx);
    }
    mut scopes_validate: std.Vector[MirResourceScope[ctx], ctx] := ctx[table.scopes];
    mut scope_validate_index := 0;
    while scope_validate_index < len(scopes_validate) {
        mut scope_validate_value := scopes_validate[scope_validate_index];
        if mir_scope_exit_cleanup_field_is_safe(scope_validate_value.scope_id, 0) == 0 ||
           mir_scope_exit_cleanup_field_is_safe(scope_validate_value.source_location, 0) == 0 ||
           mir_scope_exit_cleanup_field_is_safe(scope_validate_value.scope_exit_id, 0) == 0 ||
           mir_scope_exit_cleanup_field_is_safe(scope_validate_value.exit_program_point, 0) == 0 ||
           scope_validate_value.depth < 0 ||
           scope_validate_value.exit_sequence <= 0 ||
           mir_scope_exit_cleanup_scope_kind_selected(scope_validate_value.scope_kind) == 0
        {
            return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_scope_parent_invalid", ctx);
        }
        if scope_validate_value.selected != 1 {
            return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_unselected_scope", ctx);
        }
        if scope_validate_value.depth == 0 {
            if len(scope_validate_value.parent_scope_id) != 0 ||
               std.str_eq(scope_validate_value.scope_kind, "function_body") == 0
            {
                return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_scope_parent_invalid", ctx);
            }
        } else {
            mut parent_scope_validate := mir_scope_exit_cleanup_scope_by_id(table, scope_validate_value.parent_scope_id, ctx);
            if len(parent_scope_validate.scope_id) == 0 ||
               parent_scope_validate.depth + 1 != scope_validate_value.depth
            {
                return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_scope_parent_invalid", ctx);
            }
        }
        mut scope_duplicate_index := scope_validate_index + 1;
        while scope_duplicate_index < len(scopes_validate) {
            if std.str_eq(scopes_validate[scope_duplicate_index].scope_id, scope_validate_value.scope_id) == 1 ||
               scopes_validate[scope_duplicate_index].exit_sequence == scope_validate_value.exit_sequence
            {
                return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_duplicate_scope", ctx);
            }
            scope_duplicate_index = scope_duplicate_index + 1;
        }
        scope_validate_index = scope_validate_index + 1;
    }

    mut bindings_validate: std.Vector[MirResourceScopeBinding[ctx], ctx] := ctx[table.bindings];
    mut binding_validate_index := 0;
    while binding_validate_index < len(bindings_validate) {
        mut binding_validate_value := bindings_validate[binding_validate_index];
        if mir_scope_exit_cleanup_field_is_safe(binding_validate_value.scope_id, 0) == 0 ||
           mir_scope_exit_cleanup_field_is_safe(binding_validate_value.resource_id, 0) == 0 ||
           mir_scope_exit_cleanup_field_is_safe(binding_validate_value.value_id, 0) == 0 ||
           mir_scope_exit_cleanup_field_is_safe(binding_validate_value.carrier_id, 0) == 0 ||
           mir_scope_exit_cleanup_field_is_safe(binding_validate_value.declaration_id, 0) == 0 ||
           mir_scope_exit_cleanup_field_is_safe(binding_validate_value.source_location, 0) == 0 ||
           binding_validate_value.declaration_order <= 0 ||
           len(mir_scope_exit_cleanup_scope_by_id(table, binding_validate_value.scope_id, ctx).scope_id) == 0
        {
            return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_binding_identity_mismatch", ctx);
        }
        mut binding_duplicate_index := binding_validate_index + 1;
        while binding_duplicate_index < len(bindings_validate) {
            if std.str_eq(bindings_validate[binding_duplicate_index].resource_id, binding_validate_value.resource_id) == 1 ||
               (std.str_eq(bindings_validate[binding_duplicate_index].scope_id, binding_validate_value.scope_id) == 1 &&
                bindings_validate[binding_duplicate_index].declaration_order == binding_validate_value.declaration_order)
            {
                return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_duplicate_binding", ctx);
            }
            binding_duplicate_index = binding_duplicate_index + 1;
        }
        binding_validate_index = binding_validate_index + 1;
    }
    return mir_scope_exit_cleanup_validation(1, "scope_exit_cleanup_scope_table_valid", ctx);
}

func mir_scope_exit_cleanup_build_entry(scope_value: MirResourceScope[ctx], binding_value: MirResourceScopeBinding[ctx], cleanup_value: authority.MirCleanupObligation[ctx], execution_order: int, ctx: &Arena) MirScopeExitCleanup[ctx] {
    mut entry_build: MirScopeExitCleanup[ctx];
    entry_build.schedule_operation_id = std.Concat("operation:scope-exit:schedule:", cleanup_value.cleanup_id);
    entry_build.cleanup_operation_id = std.Concat("operation:scope-exit:destroy:", cleanup_value.cleanup_id);
    entry_build.scope_id = std.Clone(ctx, scope_value.scope_id);
    entry_build.parent_scope_id = std.Clone(ctx, scope_value.parent_scope_id);
    entry_build.resource_id = std.Clone(ctx, binding_value.resource_id);
    entry_build.value_id = std.Clone(ctx, binding_value.value_id);
    entry_build.carrier_id = std.Clone(ctx, binding_value.carrier_id);
    entry_build.cleanup_obligation_id = std.Clone(ctx, cleanup_value.cleanup_id);
    entry_build.destructor_id = std.Clone(ctx, cleanup_value.destructor_id);
    entry_build.owning_declaration = std.Clone(ctx, binding_value.declaration_id);
    entry_build.source_location = std.Clone(ctx, binding_value.source_location);
    entry_build.scope_exit_id = std.Clone(ctx, scope_value.scope_exit_id);
    entry_build.exit_program_point = std.Clone(ctx, scope_value.exit_program_point);
    entry_build.declaration_order = binding_value.declaration_order;
    entry_build.execution_order = execution_order;
    entry_build.prior_state = std.Clone(ctx, "live");
    entry_build.resulting_state = std.Clone(ctx, "destroyed");
    entry_build.observable_effect = std.Concat("destroy:", binding_value.declaration_id);
    return entry_build;
}

func mir_scope_exit_cleanup_build_exclusion(binding_value: MirResourceScopeBinding[ctx], state: str, ctx: &Arena) MirScopeExitCleanupExclusion[ctx] {
    mut exclusion_build: MirScopeExitCleanupExclusion[ctx];
    exclusion_build.scope_id = std.Clone(ctx, binding_value.scope_id);
    exclusion_build.resource_id = std.Clone(ctx, binding_value.resource_id);
    exclusion_build.value_id = std.Clone(ctx, binding_value.value_id);
    exclusion_build.carrier_id = std.Clone(ctx, binding_value.carrier_id);
    exclusion_build.state = std.Clone(ctx, state);
    exclusion_build.reason = std.Clone(ctx, mir_scope_exit_cleanup_exclusion_reason(state));
    exclusion_build.declaration_order = binding_value.declaration_order;
    exclusion_build.source_location = std.Clone(ctx, binding_value.source_location);
    return exclusion_build;
}

func mir_scope_exit_cleanup_plan_build(scope_table: MirResourceScopeTable[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) MirScopeExitCleanupPlanResult[ctx] {
    mut empty_plan_build := mir_scope_exit_cleanup_make_empty_plan(ctx);
    mut scope_validation_build := mir_scope_exit_cleanup_scope_table_validate(scope_table, ctx);
    if scope_validation_build.valid == 0 {
        return mir_scope_exit_cleanup_plan_result(0, scope_validation_build.reason_code, empty_plan_build, ctx);
    }

    mut plan_build := empty_plan_build;
    mut selected_scope_count_build := mir_scope_exit_cleanup_scope_count(scope_table, ctx);
    mut exit_sequence_build := 1;
    mut execution_order_build := 1;
    while exit_sequence_build <= selected_scope_count_build {
        mut scope_build_value := mir_scope_exit_cleanup_scope_for_sequence(scope_table, exit_sequence_build, ctx);
        if len(scope_build_value.scope_id) == 0 {
            return mir_scope_exit_cleanup_plan_result(0, "scope_exit_cleanup_scope_parent_invalid", plan_build, ctx);
        }
        mut declaration_order_build := mir_scope_exit_cleanup_max_declaration_order(scope_table, scope_build_value.scope_id, ctx);
        while declaration_order_build > 0 {
            mut binding_build_value := mir_scope_exit_cleanup_binding_for_order(scope_table, scope_build_value.scope_id, declaration_order_build, ctx);
            if len(binding_build_value.scope_id) == 0 {
                return mir_scope_exit_cleanup_plan_result(0, "scope_exit_cleanup_order_invalid", plan_build, ctx);
            }
            mut value_build_query := resource_mir.mir_resource_value_by_id(resource_table, binding_build_value.value_id, ctx);
            mut carrier_build_query := resource_mir.mir_resource_carrier_by_id(resource_table, binding_build_value.carrier_id, ctx);
            mut identity_build_query := authority.mir_resource_by_id(authority_table, binding_build_value.resource_id, ctx);
            if value_build_query.found == 0 || carrier_build_query.found == 0 || identity_build_query.found == 0 ||
               std.str_eq(value_build_query.value.resource_id, binding_build_value.resource_id) == 0 ||
               std.str_eq(carrier_build_query.value.resource_id, binding_build_value.resource_id) == 0 ||
               std.str_eq(identity_build_query.value.value_id, binding_build_value.value_id) == 0 ||
               std.str_eq(identity_build_query.value.source_declaration_id, binding_build_value.declaration_id) == 0
            {
                return mir_scope_exit_cleanup_plan_result(0, "scope_exit_cleanup_binding_identity_mismatch", plan_build, ctx);
            }
            if std.str_eq(value_build_query.value.current_state, "live") == 1 {
                mut cleanup_build_query := authority.mir_cleanup_obligation_for_resource_scope(
                    authority_table,
                    binding_build_value.resource_id,
                    scope_build_value.scope_exit_id,
                    ctx
                );
                if cleanup_build_query.found == 0 {
                    return mir_scope_exit_cleanup_plan_result(0, "scope_exit_cleanup_obligation_missing", plan_build, ctx);
                }
                if std.str_eq(cleanup_build_query.value.insertion_scope, scope_build_value.scope_id) == 0 {
                    return mir_scope_exit_cleanup_plan_result(0, "scope_exit_cleanup_wrong_scope", plan_build, ctx);
                }
                if std.str_eq(cleanup_build_query.value.destructor_id, identity_build_query.value.destructor_id) == 0 {
                    return mir_scope_exit_cleanup_plan_result(0, "scope_exit_cleanup_destructor_mismatch", plan_build, ctx);
                }
                mut entry_build_value := mir_scope_exit_cleanup_build_entry(
                    scope_build_value,
                    binding_build_value,
                    cleanup_build_query.value,
                    execution_order_build,
                    ctx
                );
                plan_build = mir_scope_exit_cleanup_plan_with_entry(plan_build, entry_build_value, ctx);
                execution_order_build = execution_order_build + 1;
            } else {
                mut exclusion_build_value := mir_scope_exit_cleanup_build_exclusion(
                    binding_build_value,
                    value_build_query.value.current_state,
                    ctx
                );
                if std.str_eq(exclusion_build_value.reason, "invalid_non_live_state") == 1 {
                    return mir_scope_exit_cleanup_plan_result(0, "scope_exit_cleanup_non_live_state_invalid", plan_build, ctx);
                }
                plan_build = mir_scope_exit_cleanup_plan_with_exclusion(plan_build, exclusion_build_value, ctx);
            }
            declaration_order_build = declaration_order_build - 1;
        }
        exit_sequence_build = exit_sequence_build + 1;
    }
    return mir_scope_exit_cleanup_plan_result(1, "scope_exit_cleanup_plan_valid", plan_build, ctx);
}

func mir_scope_exit_cleanup_entry_for_resource(plan: MirScopeExitCleanupPlan[ctx], resource_id: str, ctx: &Arena) MirScopeExitCleanup[ctx] {
    mut entries_find_resource: std.Vector[MirScopeExitCleanup[ctx], ctx] := ctx[plan.entries];
    mut entry_find_resource_index := 0;
    while entry_find_resource_index < len(entries_find_resource) {
        if std.str_eq(entries_find_resource[entry_find_resource_index].resource_id, resource_id) == 1 {
            return entries_find_resource[entry_find_resource_index];
        }
        entry_find_resource_index = entry_find_resource_index + 1;
    }
    mut missing_resource_entry: MirScopeExitCleanup[ctx];
    missing_resource_entry.resource_id = std.Clone(ctx, "");
    return missing_resource_entry;
}

func mir_scope_exit_cleanup_exclusion_for_resource(plan: MirScopeExitCleanupPlan[ctx], resource_id: str, ctx: &Arena) MirScopeExitCleanupExclusion[ctx] {
    mut exclusions_find_resource: std.Vector[MirScopeExitCleanupExclusion[ctx], ctx] := ctx[plan.exclusions];
    mut exclusion_find_resource_index := 0;
    while exclusion_find_resource_index < len(exclusions_find_resource) {
        if std.str_eq(exclusions_find_resource[exclusion_find_resource_index].resource_id, resource_id) == 1 {
            return exclusions_find_resource[exclusion_find_resource_index];
        }
        exclusion_find_resource_index = exclusion_find_resource_index + 1;
    }
    mut missing_resource_exclusion: MirScopeExitCleanupExclusion[ctx];
    missing_resource_exclusion.resource_id = std.Clone(ctx, "");
    return missing_resource_exclusion;
}

func mir_scope_exit_cleanup_validate(plan: MirScopeExitCleanupPlan[ctx], scope_table: MirResourceScopeTable[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) MirScopeExitCleanupValidation[ctx] {
    if std.str_eq(plan.format, "gust.compiler_scope_exit_cleanup.v1") == 0 ||
       std.str_eq(plan.semantic_authority, "compiler_owned_cleanup_insertion") == 0 ||
       std.str_eq(plan.order_policy, "selected_scopes_by_exit_sequence_then_reverse_declaration_order") == 0
    {
        return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_unknown_format", ctx);
    }
    mut scope_validation_plan := mir_scope_exit_cleanup_scope_table_validate(scope_table, ctx);
    if scope_validation_plan.valid == 0 { return scope_validation_plan; }

    mut entries_validate_plan: std.Vector[MirScopeExitCleanup[ctx], ctx] := ctx[plan.entries];
    mut entry_validate_plan_index := 0;
    while entry_validate_plan_index < len(entries_validate_plan) {
        mut entry_validate_plan_value := entries_validate_plan[entry_validate_plan_index];
        mut entry_duplicate_plan_index := entry_validate_plan_index + 1;
        while entry_duplicate_plan_index < len(entries_validate_plan) {
            if std.str_eq(entries_validate_plan[entry_duplicate_plan_index].cleanup_operation_id, entry_validate_plan_value.cleanup_operation_id) == 1 ||
               std.str_eq(entries_validate_plan[entry_duplicate_plan_index].cleanup_obligation_id, entry_validate_plan_value.cleanup_obligation_id) == 1 ||
               std.str_eq(entries_validate_plan[entry_duplicate_plan_index].resource_id, entry_validate_plan_value.resource_id) == 1
            {
                return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_duplicate_insertion", ctx);
            }
            entry_duplicate_plan_index = entry_duplicate_plan_index + 1;
        }
        if std.str_eq(entry_validate_plan_value.prior_state, "moved") == 1 {
            return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_moved_resource", ctx);
        }
        if std.str_eq(entry_validate_plan_value.prior_state, "live") == 0 ||
           std.str_eq(entry_validate_plan_value.resulting_state, "destroyed") == 0
        {
            return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_non_live_state_invalid", ctx);
        }
        mut binding_validate_plan_value := mir_scope_exit_cleanup_binding_for_order(
            scope_table,
            entry_validate_plan_value.scope_id,
            entry_validate_plan_value.declaration_order,
            ctx
        );
        if len(binding_validate_plan_value.scope_id) == 0 ||
           std.str_eq(binding_validate_plan_value.resource_id, entry_validate_plan_value.resource_id) == 0
        {
            return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_wrong_scope", ctx);
        }
        mut scope_validate_plan_value := mir_scope_exit_cleanup_scope_by_id(scope_table, entry_validate_plan_value.scope_id, ctx);
        if len(scope_validate_plan_value.scope_id) == 0 ||
           std.str_eq(scope_validate_plan_value.scope_exit_id, entry_validate_plan_value.scope_exit_id) == 0 ||
           std.str_eq(scope_validate_plan_value.exit_program_point, entry_validate_plan_value.exit_program_point) == 0
        {
            return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_wrong_scope", ctx);
        }
        mut identity_validate_plan_query := authority.mir_resource_by_id(authority_table, entry_validate_plan_value.resource_id, ctx);
        mut cleanup_validate_plan_query := authority.mir_cleanup_obligation_for_resource_scope(
            authority_table,
            entry_validate_plan_value.resource_id,
            entry_validate_plan_value.scope_exit_id,
            ctx
        );
        if cleanup_validate_plan_query.found == 0 {
            return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_obligation_missing", ctx);
        }
        if identity_validate_plan_query.found == 0 ||
           std.str_eq(identity_validate_plan_query.value.source_declaration_id, entry_validate_plan_value.owning_declaration) == 0
        {
            return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_owning_declaration_mismatch", ctx);
        }
        if std.str_eq(binding_validate_plan_value.source_location, entry_validate_plan_value.source_location) == 0 ||
           std.str_eq(cleanup_validate_plan_query.value.source_location, entry_validate_plan_value.source_location) == 0
        {
            return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_source_location_mismatch", ctx);
        }
        if std.str_eq(identity_validate_plan_query.value.destructor_id, entry_validate_plan_value.destructor_id) == 0 ||
           std.str_eq(cleanup_validate_plan_query.value.destructor_id, entry_validate_plan_value.destructor_id) == 0
        {
            return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_destructor_mismatch", ctx);
        }
        mut schedule_validate_plan_query := resource_mir.mir_resource_operation_by_id(
            resource_table,
            entry_validate_plan_value.schedule_operation_id,
            ctx
        );
        mut cleanup_operation_validate_plan_query := resource_mir.mir_resource_operation_by_id(
            resource_table,
            entry_validate_plan_value.cleanup_operation_id,
            ctx
        );
        if schedule_validate_plan_query.found == 0 || cleanup_operation_validate_plan_query.found == 0 {
            return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_operation_missing", ctx);
        }
        unsafe {
            if schedule_validate_plan_query.value.operation_kind.tag != 5 ||
               cleanup_operation_validate_plan_query.value.operation_kind.tag != 6
            {
                return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_operation_missing", ctx);
            }
        }
        if std.str_eq(schedule_validate_plan_query.value.resource_id, entry_validate_plan_value.resource_id) == 0 ||
           std.str_eq(cleanup_operation_validate_plan_query.value.resource_id, entry_validate_plan_value.resource_id) == 0 ||
           std.str_eq(cleanup_operation_validate_plan_query.value.cleanup_id, entry_validate_plan_value.cleanup_obligation_id) == 0 ||
           std.str_eq(cleanup_operation_validate_plan_query.value.destructor_id, entry_validate_plan_value.destructor_id) == 0 ||
           std.str_eq(cleanup_operation_validate_plan_query.value.source_location, entry_validate_plan_value.source_location) == 0
        {
            return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_operation_missing", ctx);
        }
        if resource_mir.mir_resource_cleanup_invoke_count(
            resource_table,
            entry_validate_plan_value.resource_id,
            entry_validate_plan_value.cleanup_obligation_id,
            ctx
        ) != 1
        {
            return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_duplicate_insertion", ctx);
        }
        entry_validate_plan_index = entry_validate_plan_index + 1;
    }

    mut expected_execution_order_plan := 1;
    mut selected_scope_count_plan := mir_scope_exit_cleanup_scope_count(scope_table, ctx);
    mut exit_sequence_plan := 1;
    while exit_sequence_plan <= selected_scope_count_plan {
        mut scope_order_plan_value := mir_scope_exit_cleanup_scope_for_sequence(scope_table, exit_sequence_plan, ctx);
        mut declaration_order_plan := mir_scope_exit_cleanup_max_declaration_order(scope_table, scope_order_plan_value.scope_id, ctx);
        while declaration_order_plan > 0 {
            mut binding_order_plan_value := mir_scope_exit_cleanup_binding_for_order(
                scope_table,
                scope_order_plan_value.scope_id,
                declaration_order_plan,
                ctx
            );
            mut entry_order_plan_value := mir_scope_exit_cleanup_entry_for_resource(plan, binding_order_plan_value.resource_id, ctx);
            mut exclusion_order_plan_value := mir_scope_exit_cleanup_exclusion_for_resource(plan, binding_order_plan_value.resource_id, ctx);
            if len(entry_order_plan_value.resource_id) == 0 && len(exclusion_order_plan_value.resource_id) == 0 {
                return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_live_resource_missing", ctx);
            }
            if len(entry_order_plan_value.resource_id) != 0 && len(exclusion_order_plan_value.resource_id) != 0 {
                return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_duplicate_insertion", ctx);
            }
            if len(entry_order_plan_value.resource_id) != 0 {
                if entry_order_plan_value.execution_order != expected_execution_order_plan {
                    return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_order_invalid", ctx);
                }
                expected_execution_order_plan = expected_execution_order_plan + 1;
            } else {
                mut value_exclusion_plan_query := resource_mir.mir_resource_value_by_id(
                    resource_table,
                    exclusion_order_plan_value.value_id,
                    ctx
                );
                if value_exclusion_plan_query.found == 0 ||
                   std.str_eq(value_exclusion_plan_query.value.current_state, exclusion_order_plan_value.state) == 0 ||
                   std.str_eq(exclusion_order_plan_value.reason, mir_scope_exit_cleanup_exclusion_reason(exclusion_order_plan_value.state)) == 0
                {
                    return mir_scope_exit_cleanup_validation(0, "scope_exit_cleanup_non_live_state_invalid", ctx);
                }
            }
            declaration_order_plan = declaration_order_plan - 1;
        }
        exit_sequence_plan = exit_sequence_plan + 1;
    }
    return mir_scope_exit_cleanup_validation(1, "scope_exit_cleanup_plan_valid", ctx);
}

func mir_scope_exit_cleanup_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut append_updated := std.Concat(output, key);
    append_updated = std.Concat(append_updated, ": ");
    append_updated = std.Concat(append_updated, value);
    append_updated = std.Concat(append_updated, "\n");
    return std.Clone(ctx, append_updated);
}

func mir_scope_exit_cleanup_append_to_request(request: str, scope_table: MirResourceScopeTable[ctx], plan: MirScopeExitCleanupPlan[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut append_validation := mir_scope_exit_cleanup_validate(plan, scope_table, resource_table, authority_table, ctx);
    if append_validation.valid == 0 {
        mut append_invalid := std.Concat(request, "scope_exit_cleanup_format: invalid\nscope_exit_cleanup_reason: ");
        append_invalid = std.Concat(append_invalid, append_validation.reason_code);
        append_invalid = std.Concat(append_invalid, "\n");
        return std.Clone(ctx, append_invalid);
    }
    mut append_output := std.Clone(ctx, request);
    append_output = mir_scope_exit_cleanup_append_field(append_output, "scope_exit_cleanup_format", plan.format, ctx);
    append_output = mir_scope_exit_cleanup_append_field(append_output, "scope_exit_cleanup_semantic_authority", plan.semantic_authority, ctx);
    append_output = mir_scope_exit_cleanup_append_field(append_output, "scope_exit_cleanup_order_policy", plan.order_policy, ctx);
    append_output = mir_scope_exit_cleanup_append_field(append_output, "scope_exit_cleanup_scope_count", std.FormatInt(mir_scope_exit_cleanup_scope_count(scope_table, ctx)), ctx);
    append_output = mir_scope_exit_cleanup_append_field(append_output, "scope_exit_cleanup_binding_count", std.FormatInt(mir_scope_exit_cleanup_binding_count(scope_table, ctx)), ctx);
    append_output = mir_scope_exit_cleanup_append_field(append_output, "scope_exit_cleanup_entry_count", std.FormatInt(mir_scope_exit_cleanup_entry_count(plan, ctx)), ctx);
    append_output = mir_scope_exit_cleanup_append_field(append_output, "scope_exit_cleanup_exclusion_count", std.FormatInt(mir_scope_exit_cleanup_exclusion_count(plan, ctx)), ctx);

    mut append_scope_index := 0;
    while append_scope_index < mir_scope_exit_cleanup_scope_count(scope_table, ctx) {
        mut append_scope_value := mir_scope_exit_cleanup_scope_at(scope_table, append_scope_index, ctx);
        mut append_scope_prefix := std.Concat("scope_exit_cleanup_scope_", std.FormatInt(append_scope_index));
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_scope_prefix, "_scope_id"), append_scope_value.scope_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_scope_prefix, "_parent_scope_id"), append_scope_value.parent_scope_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_scope_prefix, "_scope_kind"), append_scope_value.scope_kind, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_scope_prefix, "_source_location"), append_scope_value.source_location, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_scope_prefix, "_scope_exit_id"), append_scope_value.scope_exit_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_scope_prefix, "_exit_program_point"), append_scope_value.exit_program_point, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_scope_prefix, "_depth"), std.FormatInt(append_scope_value.depth), ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_scope_prefix, "_exit_sequence"), std.FormatInt(append_scope_value.exit_sequence), ctx);
        append_scope_index = append_scope_index + 1;
    }

    mut append_binding_index := 0;
    while append_binding_index < mir_scope_exit_cleanup_binding_count(scope_table, ctx) {
        mut append_binding_value := mir_scope_exit_cleanup_binding_at(scope_table, append_binding_index, ctx);
        mut append_binding_prefix := std.Concat("scope_exit_cleanup_binding_", std.FormatInt(append_binding_index));
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_binding_prefix, "_scope_id"), append_binding_value.scope_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_binding_prefix, "_resource_id"), append_binding_value.resource_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_binding_prefix, "_value_id"), append_binding_value.value_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_binding_prefix, "_carrier_id"), append_binding_value.carrier_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_binding_prefix, "_declaration_id"), append_binding_value.declaration_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_binding_prefix, "_declaration_order"), std.FormatInt(append_binding_value.declaration_order), ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_binding_prefix, "_source_location"), append_binding_value.source_location, ctx);
        append_binding_index = append_binding_index + 1;
    }

    mut append_entry_index := 0;
    while append_entry_index < mir_scope_exit_cleanup_entry_count(plan, ctx) {
        mut append_entry_value := mir_scope_exit_cleanup_entry_at(plan, append_entry_index, ctx);
        mut append_entry_prefix := std.Concat("scope_exit_cleanup_entry_", std.FormatInt(append_entry_index));
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_schedule_operation_id"), append_entry_value.schedule_operation_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_cleanup_operation_id"), append_entry_value.cleanup_operation_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_scope_id"), append_entry_value.scope_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_parent_scope_id"), append_entry_value.parent_scope_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_resource_id"), append_entry_value.resource_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_value_id"), append_entry_value.value_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_carrier_id"), append_entry_value.carrier_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_cleanup_obligation_id"), append_entry_value.cleanup_obligation_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_destructor_id"), append_entry_value.destructor_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_owning_declaration"), append_entry_value.owning_declaration, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_source_location"), append_entry_value.source_location, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_scope_exit_id"), append_entry_value.scope_exit_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_exit_program_point"), append_entry_value.exit_program_point, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_declaration_order"), std.FormatInt(append_entry_value.declaration_order), ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_execution_order"), std.FormatInt(append_entry_value.execution_order), ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_prior_state"), append_entry_value.prior_state, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_resulting_state"), append_entry_value.resulting_state, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_entry_prefix, "_observable_effect"), append_entry_value.observable_effect, ctx);
        append_entry_index = append_entry_index + 1;
    }

    mut append_exclusion_index := 0;
    while append_exclusion_index < mir_scope_exit_cleanup_exclusion_count(plan, ctx) {
        mut append_exclusion_value := mir_scope_exit_cleanup_exclusion_at(plan, append_exclusion_index, ctx);
        mut append_exclusion_prefix := std.Concat("scope_exit_cleanup_exclusion_", std.FormatInt(append_exclusion_index));
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_exclusion_prefix, "_scope_id"), append_exclusion_value.scope_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_exclusion_prefix, "_resource_id"), append_exclusion_value.resource_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_exclusion_prefix, "_value_id"), append_exclusion_value.value_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_exclusion_prefix, "_carrier_id"), append_exclusion_value.carrier_id, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_exclusion_prefix, "_state"), append_exclusion_value.state, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_exclusion_prefix, "_reason"), append_exclusion_value.reason, ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_exclusion_prefix, "_declaration_order"), std.FormatInt(append_exclusion_value.declaration_order), ctx);
        append_output = mir_scope_exit_cleanup_append_field(append_output, std.Concat(append_exclusion_prefix, "_source_location"), append_exclusion_value.source_location, ctx);
        append_exclusion_index = append_exclusion_index + 1;
    }
    return std.Clone(ctx, append_output);
}

func mir_scope_exit_cleanup_witness(plan: MirScopeExitCleanupPlan[ctx], scope_table: MirResourceScopeTable[ctx], resource_table: resource_mir.MirResourceMirTable[ctx], authority_table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut witness_validation := mir_scope_exit_cleanup_validate(plan, scope_table, resource_table, authority_table, ctx);
    if witness_validation.valid == 0 {
        mut witness_rejected := "scope_exit_cleanup_witness: rejected reason=";
        witness_rejected = std.Concat(witness_rejected, witness_validation.reason_code);
        witness_rejected = std.Concat(witness_rejected, "\n");
        return std.Clone(ctx, witness_rejected);
    }
    mut witness_output := "scope_exit_cleanup_witness: accepted order_policy=reverse_declaration_order\n";
    mut witness_entry_index := 0;
    while witness_entry_index < mir_scope_exit_cleanup_entry_count(plan, ctx) {
        mut witness_entry_value := mir_scope_exit_cleanup_entry_at(plan, witness_entry_index, ctx);
        mut witness_entry_row := "scope_exit_cleanup: scope=";
        witness_entry_row = std.Concat(witness_entry_row, witness_entry_value.scope_id);
        witness_entry_row = std.Concat(witness_entry_row, " resource=");
        witness_entry_row = std.Concat(witness_entry_row, witness_entry_value.resource_id);
        witness_entry_row = std.Concat(witness_entry_row, " order=");
        witness_entry_row = std.Concat(witness_entry_row, std.FormatInt(witness_entry_value.execution_order));
        witness_entry_row = std.Concat(witness_entry_row, " declaration_order=");
        witness_entry_row = std.Concat(witness_entry_row, std.FormatInt(witness_entry_value.declaration_order));
        witness_entry_row = std.Concat(witness_entry_row, " destructor=");
        witness_entry_row = std.Concat(witness_entry_row, witness_entry_value.destructor_id);
        witness_entry_row = std.Concat(witness_entry_row, " source=");
        witness_entry_row = std.Concat(witness_entry_row, witness_entry_value.source_location);
        witness_entry_row = std.Concat(witness_entry_row, " operation=");
        witness_entry_row = std.Concat(witness_entry_row, witness_entry_value.cleanup_operation_id);
        witness_entry_row = std.Concat(witness_entry_row, " effect=");
        witness_entry_row = std.Concat(witness_entry_row, witness_entry_value.observable_effect);
        witness_entry_row = std.Concat(witness_entry_row, "\n");
        witness_output = std.Concat(witness_output, witness_entry_row);
        witness_entry_index = witness_entry_index + 1;
    }
    mut witness_exclusion_index := 0;
    while witness_exclusion_index < mir_scope_exit_cleanup_exclusion_count(plan, ctx) {
        mut witness_exclusion_value := mir_scope_exit_cleanup_exclusion_at(plan, witness_exclusion_index, ctx);
        mut witness_exclusion_row := "scope_exit_cleanup_excluded: scope=";
        witness_exclusion_row = std.Concat(witness_exclusion_row, witness_exclusion_value.scope_id);
        witness_exclusion_row = std.Concat(witness_exclusion_row, " resource=");
        witness_exclusion_row = std.Concat(witness_exclusion_row, witness_exclusion_value.resource_id);
        witness_exclusion_row = std.Concat(witness_exclusion_row, " state=");
        witness_exclusion_row = std.Concat(witness_exclusion_row, witness_exclusion_value.state);
        witness_exclusion_row = std.Concat(witness_exclusion_row, " reason=");
        witness_exclusion_row = std.Concat(witness_exclusion_row, witness_exclusion_value.reason);
        witness_exclusion_row = std.Concat(witness_exclusion_row, "\n");
        witness_output = std.Concat(witness_output, witness_exclusion_row);
        witness_exclusion_index = witness_exclusion_index + 1;
    }
    return std.Clone(ctx, witness_output);
}