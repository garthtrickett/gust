// Patch 15.11 directory and selected specialized resource kinds.
// The selected inventory contains only os_Dir_ctx. Its constructor, identity,
// destructor/close, move/copy/close policy, cleanup effect, runtime symbols,
// target set, and layout are frozen here. State and cleanup decisions remain
// owned by MirResourceAuthorityTable; neither backend gets a specialized state
// machine. os_DirEntry_ctx is a borrowed observation and is not a resource.

import "mir_resource_authority.gst" as authority;

type MirSpecializedResourceKind[ctx] struct {
    kind_id: str,
    resource_type_id: str,
    constructor_id: str,
    destructor_id: str,
    close_capability_id: str,
    copy_policy: str,
    move_policy: str,
    close_policy: str,
    cleanup_effect: str,
    constructor_runtime_symbol: str,
    close_runtime_symbol: str,
    target_applicability: str,
    layout_id: str
}

type MirSpecializedResourceInstance[ctx] struct {
    resource_id: str,
    kind_id: str,
    final_state: str,
    operation_sequence: str,
    observed_entry_count: int,
    close_count: int,
    destructor_count: int,
    filesystem_effect: str
}

type MirSpecializedResourcePlan[ctx] struct {
    format: str,
    semantic_authority: str,
    selected_kinds: str,
    non_resource_views: str,
    backend_policy: str,
    kind: MirSpecializedResourceKind[ctx],
    instances: Index[std.Vector[MirSpecializedResourceInstance[ctx], ctx], ctx]
}

type MirSpecializedResourceValidation[ctx] struct { valid: int, reason_code: str }

func mir_specialized_resource_empty_instances(ctx: &Arena) Index[std.Vector[MirSpecializedResourceInstance[ctx], ctx], ctx] {
    mut values: std.Vector[MirSpecializedResourceInstance[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirSpecializedResourceInstance[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_specialized_resource_make_directory_plan(ctx: &Arena) MirSpecializedResourcePlan[ctx] {
    mut plan: MirSpecializedResourcePlan[ctx];
    plan.format = std.Clone(ctx, "gust.compiler_specialized_resource.v1");
    plan.semantic_authority = std.Clone(ctx, "compiler_owned_generic_resource_and_lifetime_authority");
    plan.selected_kinds = std.Clone(ctx, "os_Dir_ctx");
    plan.non_resource_views = std.Clone(ctx, "os_DirEntry_ctx");
    plan.backend_policy = std.Clone(ctx, "no_specialized_backend_state_machine");
    plan.kind.kind_id = std.Clone(ctx, "directory");
    plan.kind.resource_type_id = std.Clone(ctx, "os_Dir_ctx");
    plan.kind.constructor_id = std.Clone(ctx, "os.OpenDir");
    plan.kind.destructor_id = std.Clone(ctx, "destructor:os.CloseDir");
    plan.kind.close_capability_id = std.Clone(ctx, "close:os.CloseDir");
    plan.kind.copy_policy = std.Clone(ctx, "prohibited");
    plan.kind.move_policy = std.Clone(ctx, "immovable_while_open");
    plan.kind.close_policy = std.Clone(ctx, "manual_or_scope_exit_exactly_once");
    plan.kind.cleanup_effect = std.Clone(ctx, "close_directory_handle");
    plan.kind.constructor_runtime_symbol = std.Clone(ctx, "os_OpenDir");
    plan.kind.close_runtime_symbol = std.Clone(ctx, "os_CloseDir");
    plan.kind.target_applicability = std.Clone(ctx, "all_declared_host_targets_from_phase14_target_authority");
    plan.kind.layout_id = std.Clone(ctx, "layout:os_dir");
    plan.instances = mir_specialized_resource_empty_instances(ctx);
    return plan;
}

func mir_specialized_resource_with_instance(plan: MirSpecializedResourcePlan[ctx], instance: MirSpecializedResourceInstance[ctx], ctx: &Arena) MirSpecializedResourcePlan[ctx] {
    mut updated := plan;
    mut values: std.Vector[MirSpecializedResourceInstance[ctx], ctx] := ctx[updated.instances];
    values.Push(instance);
    ctx.Set(updated.instances, values);
    return updated;
}

func mir_specialized_resource_validation(valid: int, reason: str, ctx: &Arena) MirSpecializedResourceValidation[ctx] {
    mut result: MirSpecializedResourceValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason);
    return result;
}

func mir_specialized_resource_validate(plan: MirSpecializedResourcePlan[ctx], table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) MirSpecializedResourceValidation[ctx] {
    if std.str_eq(plan.format, "gust.compiler_specialized_resource.v1") == 0 { return mir_specialized_resource_validation(0, "specialized_resource_unknown_format", ctx); }
    if std.str_eq(plan.semantic_authority, "compiler_owned_generic_resource_and_lifetime_authority") == 0 ||
       std.str_eq(plan.backend_policy, "no_specialized_backend_state_machine") == 0
    { return mir_specialized_resource_validation(0, "specialized_resource_authority_mismatch", ctx); }
    if std.str_eq(plan.selected_kinds, "os_Dir_ctx") == 0 || std.str_eq(plan.non_resource_views, "os_DirEntry_ctx") == 0 {
        return mir_specialized_resource_validation(0, "specialized_resource_inventory_unfrozen", ctx);
    }
    mut kind := plan.kind;
    if std.str_eq(kind.kind_id, "directory") == 0 || std.str_eq(kind.resource_type_id, "os_Dir_ctx") == 0 ||
       std.str_eq(kind.constructor_id, "os.OpenDir") == 0 || std.str_eq(kind.destructor_id, "destructor:os.CloseDir") == 0 ||
       std.str_eq(kind.close_capability_id, "close:os.CloseDir") == 0 || std.str_eq(kind.copy_policy, "prohibited") == 0 ||
       std.str_eq(kind.move_policy, "immovable_while_open") == 0 || std.str_eq(kind.close_policy, "manual_or_scope_exit_exactly_once") == 0 ||
       std.str_eq(kind.cleanup_effect, "close_directory_handle") == 0 || std.str_eq(kind.constructor_runtime_symbol, "os_OpenDir") == 0 ||
       std.str_eq(kind.close_runtime_symbol, "os_CloseDir") == 0 || std.str_eq(kind.target_applicability, "all_declared_host_targets_from_phase14_target_authority") == 0 ||
       std.str_eq(kind.layout_id, "layout:os_dir") == 0
    { return mir_specialized_resource_validation(0, "specialized_resource_kind_contract_mismatch", ctx); }
    mut destructor := authority.mir_destructor_for(table, kind.resource_type_id, ctx);
    mut close_capability := authority.mir_close_capability_for(table, kind.resource_type_id, ctx);
    if destructor.found == 0 || std.str_eq(destructor.value.destructor_id, kind.destructor_id) == 0 || std.str_eq(destructor.value.runtime_symbol, kind.close_runtime_symbol) == 0 {
        return mir_specialized_resource_validation(0, "specialized_resource_destructor_mismatch", ctx);
    }
    if close_capability.found == 0 || std.str_eq(close_capability.value.close_capability_id, kind.close_capability_id) == 0 ||
       std.str_eq(close_capability.value.runtime_symbol, kind.close_runtime_symbol) == 0 || close_capability.value.suppresses_deferred_cleanup != 1
    { return mir_specialized_resource_validation(0, "specialized_resource_close_capability_mismatch", ctx); }
    mut instances: std.Vector[MirSpecializedResourceInstance[ctx], ctx] := ctx[plan.instances];
    if len(instances) == 0 { return mir_specialized_resource_validation(0, "specialized_resource_instance_missing", ctx); }
    mut index := 0;
    while index < len(instances) {
        mut instance := instances[index];
        mut resource := authority.mir_resource_by_id(table, instance.resource_id, ctx);
        if resource.found == 0 { return mir_specialized_resource_validation(0, "specialized_resource_unknown_resource_id", ctx); }
        if std.str_eq(resource.value.resource_kind, kind.kind_id) == 0 || std.str_eq(resource.value.resource_type_id, kind.resource_type_id) == 0 ||
           std.str_eq(resource.value.destructor_id, kind.destructor_id) == 0 || std.str_eq(resource.value.close_capability_id, kind.close_capability_id) == 0 ||
           std.str_eq(resource.value.copy_policy, kind.copy_policy) == 0 || std.str_eq(resource.value.move_policy, kind.move_policy) == 0 ||
           std.str_eq(resource.value.layout_id, kind.layout_id) == 0
        { return mir_specialized_resource_validation(0, "specialized_resource_generic_metadata_mismatch", ctx); }
        if std.str_eq(instance.kind_id, kind.kind_id) == 0 || std.str_eq(instance.final_state, "manually_closed") == 0 ||
           std.str_eq(instance.operation_sequence, "open_read_close") == 0 || instance.observed_entry_count < 1 ||
           instance.close_count != 1 || instance.destructor_count != 0 || std.str_eq(instance.filesystem_effect, "directory_entry_observed") == 0
        { return mir_specialized_resource_validation(0, "specialized_resource_effect_mismatch", ctx); }
        mut latest := authority.mir_resource_latest_state(table, instance.resource_id, ctx);
        if latest.found == 0 || std.str_eq(latest.value.state, instance.final_state) == 0 {
            return mir_specialized_resource_validation(0, "specialized_resource_state_mismatch", ctx);
        }
        index = index + 1;
    }
    return mir_specialized_resource_validation(1, "specialized_resource_valid", ctx);
}

func mir_specialized_resource_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat(output, std.Concat(key, std.Concat(": ", std.Concat(value, "\n")))));
}

func mir_specialized_resource_append_to_request(base: str, plan: MirSpecializedResourcePlan[ctx], table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_specialized_resource_validate(plan, table, ctx);
    if validation.valid == 0 {
        mut stable_reason := std.Clone(ctx, validation.reason_code);
        return mir_specialized_resource_append_field(base, "specialized_resource_error", stable_reason, ctx);
    }
    mut output := std.Clone(ctx, base);
    output = mir_specialized_resource_append_field(output, "specialized_resource_format", plan.format, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_semantic_authority", plan.semantic_authority, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_selected_kinds", plan.selected_kinds, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_non_resource_views", plan.non_resource_views, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_backend_policy", plan.backend_policy, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_kind_id", plan.kind.kind_id, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_type_id", plan.kind.resource_type_id, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_constructor_id", plan.kind.constructor_id, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_destructor_id", plan.kind.destructor_id, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_close_capability_id", plan.kind.close_capability_id, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_copy_policy", plan.kind.copy_policy, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_move_policy", plan.kind.move_policy, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_close_policy", plan.kind.close_policy, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_cleanup_effect", plan.kind.cleanup_effect, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_constructor_runtime_symbol", plan.kind.constructor_runtime_symbol, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_close_runtime_symbol", plan.kind.close_runtime_symbol, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_target_applicability", plan.kind.target_applicability, ctx);
    output = mir_specialized_resource_append_field(output, "specialized_resource_layout_id", plan.kind.layout_id, ctx);
    mut instances: std.Vector[MirSpecializedResourceInstance[ctx], ctx] := ctx[plan.instances];
    output = mir_specialized_resource_append_field(output, "specialized_resource_instance_count", std.FormatInt(len(instances)), ctx);
    mut index := 0;
    while index < len(instances) {
        mut prefix := std.Concat("specialized_resource_instance_", std.FormatInt(index));
        output = mir_specialized_resource_append_field(output, std.Concat(prefix, "_resource_id"), instances[index].resource_id, ctx);
        output = mir_specialized_resource_append_field(output, std.Concat(prefix, "_kind_id"), instances[index].kind_id, ctx);
        output = mir_specialized_resource_append_field(output, std.Concat(prefix, "_final_state"), instances[index].final_state, ctx);
        output = mir_specialized_resource_append_field(output, std.Concat(prefix, "_operation_sequence"), instances[index].operation_sequence, ctx);
        output = mir_specialized_resource_append_field(output, std.Concat(prefix, "_observed_entry_count"), std.FormatInt(instances[index].observed_entry_count), ctx);
        output = mir_specialized_resource_append_field(output, std.Concat(prefix, "_close_count"), std.FormatInt(instances[index].close_count), ctx);
        output = mir_specialized_resource_append_field(output, std.Concat(prefix, "_destructor_count"), std.FormatInt(instances[index].destructor_count), ctx);
        output = mir_specialized_resource_append_field(output, std.Concat(prefix, "_filesystem_effect"), instances[index].filesystem_effect, ctx);
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_specialized_resource_witness(plan: MirSpecializedResourcePlan[ctx], table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_specialized_resource_validate(plan, table, ctx);
    if validation.valid == 0 { return std.Clone(ctx, std.Concat("specialized_resource_error: reason=", validation.reason_code)); }
    mut output := "specialized_resource_policy: authority=compiler selected_kinds=os_Dir_ctx generic_state_machine=1 backend_local_state_machine=0 non_resource_views=os_DirEntry_ctx\n";
    output = std.Concat(output, "specialized_resource_kind: kind=directory resource_type=os_Dir_ctx constructor=os.OpenDir destructor=os.CloseDir close=os.CloseDir copy=prohibited move=immovable_while_open cleanup=manual_or_scope_exit_exactly_once runtime_constructor=os_OpenDir runtime_close=os_CloseDir targets=all_declared_host_targets_from_phase14_target_authority layout=layout:os_dir\n");
    mut instances: std.Vector[MirSpecializedResourceInstance[ctx], ctx] := ctx[plan.instances];
    mut total_close := 0;
    mut total_destructor := 0;
    mut index := 0;
    while index < len(instances) {
        mut instance := instances[index];
        mut line := std.Concat("specialized_resource: resource=", instance.resource_id);
        line = std.Concat(line, std.Concat(" kind=", instance.kind_id));
        line = std.Concat(line, std.Concat(" state=", instance.final_state));
        line = std.Concat(line, std.Concat(" operation=", instance.operation_sequence));
        line = std.Concat(line, std.Concat(" entries_observed=", std.FormatInt(instance.observed_entry_count)));
        line = std.Concat(line, std.Concat(" close_count=", std.FormatInt(instance.close_count)));
        line = std.Concat(line, std.Concat(" destructor_count=", std.FormatInt(instance.destructor_count)));
        line = std.Concat(line, std.Concat(" filesystem_effect=", std.Concat(instance.filesystem_effect, "\n")));
        output = std.Concat(output, line);
        total_close = total_close + instance.close_count;
        total_destructor = total_destructor + instance.destructor_count;
        index = index + 1;
    }
    output = std.Concat(output, "specialized_resource_witness: selected_kind_count=1 resource_count=");
    output = std.Concat(output, std.FormatInt(len(instances)));
    output = std.Concat(output, " close_count=");
    output = std.Concat(output, std.FormatInt(total_close));
    output = std.Concat(output, " destructor_count=");
    output = std.Concat(output, std.FormatInt(total_destructor));
    output = std.Concat(output, " filesystem_effects_compared=1 generic_authority=1\n");
    return std.Clone(ctx, output);
}
