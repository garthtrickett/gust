// Patch 15.6 compiler-owned cleanup insertion for early returns and selected structured exits.
//
// This sidecar records canonical early edges, their exited lexical scope chain,
// return evaluation/terminator positions, and the exact cleanup entries that
// must execute before control transfers.

type MirEarlyExitEdge[ctx] struct {
    edge_id: str,
    exit_kind: str,
    source_scope_id: str,
    destination_scope_id: str,
    return_value_id: str,
    return_abi: str,
    return_evaluation_order: int,
    cleanup_begin_order: int,
    terminator_order: int,
    source_location: str,
    exited_scope_chain: str
}

type MirEarlyExitCleanup[ctx] struct {
    edge_id: str,
    scope_id: str,
    resource_id: str,
    cleanup_operation_id: str,
    destructor_id: str,
    owning_declaration: str,
    source_location: str,
    scope_depth: int,
    declaration_order: int,
    execution_order: int,
    prior_state: str,
    observable_effect: str
}

type MirEarlyExitCleanupExclusion[ctx] struct {
    edge_id: str,
    scope_id: str,
    resource_id: str,
    state: str,
    reason: str
}

type MirEarlyExitCleanupPlan[ctx] struct {
    format: str,
    semantic_authority: str,
    order_policy: str,
    selected_exit_kinds: str,
    aggregate_return_policy: str,
    edges: Index[std.Vector[MirEarlyExitEdge[ctx], ctx], ctx],
    entries: Index[std.Vector[MirEarlyExitCleanup[ctx], ctx], ctx],
    exclusions: Index[std.Vector[MirEarlyExitCleanupExclusion[ctx], ctx], ctx]
}

type MirEarlyExitCleanupValidation[ctx] struct {
    valid: int,
    reason_code: str
}

func mir_early_exit_cleanup_empty_edge_vector(ctx: &Arena) Index[std.Vector[MirEarlyExitEdge[ctx], ctx], ctx] {
    mut values: std.Vector[MirEarlyExitEdge[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirEarlyExitEdge[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_early_exit_cleanup_empty_entry_vector(ctx: &Arena) Index[std.Vector[MirEarlyExitCleanup[ctx], ctx], ctx] {
    mut values: std.Vector[MirEarlyExitCleanup[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirEarlyExitCleanup[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_early_exit_cleanup_empty_exclusion_vector(ctx: &Arena) Index[std.Vector[MirEarlyExitCleanupExclusion[ctx], ctx], ctx] {
    mut values: std.Vector[MirEarlyExitCleanupExclusion[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirEarlyExitCleanupExclusion[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_early_exit_cleanup_make_plan(ctx: &Arena) MirEarlyExitCleanupPlan[ctx] {
    mut plan: MirEarlyExitCleanupPlan[ctx];
    plan.format = std.Clone(ctx, "gust.compiler_early_exit_cleanup.v1");
    plan.semantic_authority = std.Clone(ctx, "compiler_owned_early_exit_cleanup");
    plan.order_policy = std.Clone(ctx, "inner_scope_before_outer_scope_then_reverse_declaration_order");
    plan.selected_exit_kinds = std.Clone(ctx, "direct_return,nested_conditional_return,selected_loop_return,selected_break,selected_continue");
    plan.aggregate_return_policy = std.Clone(ctx, "deferred_to_phase16");
    plan.edges = mir_early_exit_cleanup_empty_edge_vector(ctx);
    plan.entries = mir_early_exit_cleanup_empty_entry_vector(ctx);
    plan.exclusions = mir_early_exit_cleanup_empty_exclusion_vector(ctx);
    return plan;
}

func mir_early_exit_cleanup_with_edge(plan: MirEarlyExitCleanupPlan[ctx], edge: MirEarlyExitEdge[ctx], ctx: &Arena) MirEarlyExitCleanupPlan[ctx] {
    mut updated := plan;
    mut values: std.Vector[MirEarlyExitEdge[ctx], ctx] := ctx[updated.edges];
    values.Push(edge);
    ctx.Set(updated.edges, values);
    return updated;
}

func mir_early_exit_cleanup_with_entry(plan: MirEarlyExitCleanupPlan[ctx], entry: MirEarlyExitCleanup[ctx], ctx: &Arena) MirEarlyExitCleanupPlan[ctx] {
    mut updated := plan;
    mut values: std.Vector[MirEarlyExitCleanup[ctx], ctx] := ctx[updated.entries];
    values.Push(entry);
    ctx.Set(updated.entries, values);
    return updated;
}

func mir_early_exit_cleanup_with_exclusion(plan: MirEarlyExitCleanupPlan[ctx], exclusion: MirEarlyExitCleanupExclusion[ctx], ctx: &Arena) MirEarlyExitCleanupPlan[ctx] {
    mut updated := plan;
    mut values: std.Vector[MirEarlyExitCleanupExclusion[ctx], ctx] := ctx[updated.exclusions];
    values.Push(exclusion);
    ctx.Set(updated.exclusions, values);
    return updated;
}

func mir_early_exit_cleanup_edge_count(plan: MirEarlyExitCleanupPlan[ctx], ctx: &Arena) int {
    mut values: std.Vector[MirEarlyExitEdge[ctx], ctx] := ctx[plan.edges];
    return len(values);
}

func mir_early_exit_cleanup_edge_at(plan: MirEarlyExitCleanupPlan[ctx], position: int, ctx: &Arena) MirEarlyExitEdge[ctx] {
    mut values: std.Vector[MirEarlyExitEdge[ctx], ctx] := ctx[plan.edges];
    return values[position];
}

func mir_early_exit_cleanup_entry_count(plan: MirEarlyExitCleanupPlan[ctx], ctx: &Arena) int {
    mut values: std.Vector[MirEarlyExitCleanup[ctx], ctx] := ctx[plan.entries];
    return len(values);
}

func mir_early_exit_cleanup_entry_at(plan: MirEarlyExitCleanupPlan[ctx], position: int, ctx: &Arena) MirEarlyExitCleanup[ctx] {
    mut values: std.Vector[MirEarlyExitCleanup[ctx], ctx] := ctx[plan.entries];
    return values[position];
}

func mir_early_exit_cleanup_exclusion_count(plan: MirEarlyExitCleanupPlan[ctx], ctx: &Arena) int {
    mut values: std.Vector[MirEarlyExitCleanupExclusion[ctx], ctx] := ctx[plan.exclusions];
    return len(values);
}

func mir_early_exit_cleanup_exclusion_at(plan: MirEarlyExitCleanupPlan[ctx], position: int, ctx: &Arena) MirEarlyExitCleanupExclusion[ctx] {
    mut values: std.Vector[MirEarlyExitCleanupExclusion[ctx], ctx] := ctx[plan.exclusions];
    return values[position];
}

func mir_early_exit_cleanup_exit_kind_selected(kind: str) int {
    if std.str_eq(kind, "direct_return") == 1 { return 1; }
    if std.str_eq(kind, "nested_conditional_return") == 1 { return 1; }
    if std.str_eq(kind, "selected_loop_return") == 1 { return 1; }
    if std.str_eq(kind, "selected_break") == 1 { return 1; }
    if std.str_eq(kind, "selected_continue") == 1 { return 1; }
    return 0;
}

func mir_early_exit_cleanup_validate(plan: MirEarlyExitCleanupPlan[ctx], ctx: &Arena) MirEarlyExitCleanupValidation[ctx] {
    mut result: MirEarlyExitCleanupValidation[ctx];
    result.valid = 0;
    result.reason_code = std.Clone(ctx, "early_return_cleanup_unknown");

    mut edges: std.Vector[MirEarlyExitEdge[ctx], ctx] := ctx[plan.edges];
    mut entries: std.Vector[MirEarlyExitCleanup[ctx], ctx] := ctx[plan.entries];
    mut edge_index := 0;
    while edge_index < len(edges) {
        mut edge := edges[edge_index];
        if mir_early_exit_cleanup_exit_kind_selected(edge.exit_kind) == 0 {
            result.reason_code = std.Clone(ctx, "early_return_cleanup_exit_kind_unselected");
            return result;
        }
        if std.str_eq(edge.return_abi, "aggregate") == 1 {
            result.reason_code = std.Clone(ctx, "early_return_cleanup_aggregate_return_deferred");
            return result;
        }
        if edge.return_evaluation_order >= edge.cleanup_begin_order || edge.cleanup_begin_order >= edge.terminator_order {
            result.reason_code = std.Clone(ctx, "early_return_cleanup_return_order_invalid");
            return result;
        }
        mut previous_depth := 2147483647;
        mut previous_declaration := 2147483647;
        mut expected_order := 1;
        mut matching := 0;
        mut entry_index := 0;
        while entry_index < len(entries) {
            mut entry := entries[entry_index];
            if std.str_eq(entry.edge_id, edge.edge_id) == 1 {
                matching = matching + 1;
                if std.str_eq(entry.prior_state, "live") == 0 {
                    result.reason_code = std.Clone(ctx, "early_return_cleanup_non_live_resource");
                    return result;
                }
                if entry.execution_order != expected_order {
                    result.reason_code = std.Clone(ctx, "early_return_cleanup_order_invalid");
                    return result;
                }
                if entry.scope_depth > previous_depth {
                    result.reason_code = std.Clone(ctx, "early_return_cleanup_inner_outer_order_invalid");
                    return result;
                }
                if entry.scope_depth == previous_depth && entry.declaration_order >= previous_declaration {
                    result.reason_code = std.Clone(ctx, "early_return_cleanup_order_invalid");
                    return result;
                }
                if entry.execution_order >= edge.terminator_order {
                    result.reason_code = std.Clone(ctx, "early_return_cleanup_after_terminator");
                    return result;
                }
                previous_depth = entry.scope_depth;
                previous_declaration = entry.declaration_order;
                expected_order = expected_order + 1;
            }
            entry_index = entry_index + 1;
        }
        if matching == 0 {
            result.reason_code = std.Clone(ctx, "early_return_cleanup_missing");
            return result;
        }
        edge_index = edge_index + 1;
    }

    mut duplicate_left := 0;
    while duplicate_left < len(entries) {
        mut duplicate_right := duplicate_left + 1;
        while duplicate_right < len(entries) {
            if std.str_eq(entries[duplicate_left].cleanup_operation_id, entries[duplicate_right].cleanup_operation_id) == 1 {
                result.reason_code = std.Clone(ctx, "early_return_cleanup_duplicate_shared_edge");
                return result;
            }
            duplicate_right = duplicate_right + 1;
        }
        duplicate_left = duplicate_left + 1;
    }

    result.valid = 1;
    result.reason_code = std.Clone(ctx, "early_return_cleanup_valid");
    return result;
}

func mir_early_exit_cleanup_append_field(output: str, key: str, value: str) str {
    return std.Concat(output, std.Concat(key, std.Concat(": ", std.Concat(value, "\n"))));
}

func mir_early_exit_cleanup_append_to_request(request: str, plan: MirEarlyExitCleanupPlan[ctx], ctx: &Arena) str {
    mut output := request;
    output = mir_early_exit_cleanup_append_field(output, "early_exit_cleanup_format", plan.format);
    output = mir_early_exit_cleanup_append_field(output, "early_exit_cleanup_order_policy", plan.order_policy);
    output = mir_early_exit_cleanup_append_field(output, "early_exit_cleanup_aggregate_return_policy", plan.aggregate_return_policy);
    output = mir_early_exit_cleanup_append_field(output, "early_exit_cleanup_edge_count", std.FormatInt(mir_early_exit_cleanup_edge_count(plan, ctx)));
    mut edge_index := 0;
    while edge_index < mir_early_exit_cleanup_edge_count(plan, ctx) {
        mut edge := mir_early_exit_cleanup_edge_at(plan, edge_index, ctx);
        mut prefix := std.Concat("early_exit_cleanup_edge_", std.FormatInt(edge_index));
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_id"), edge.edge_id);
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_kind"), edge.exit_kind);
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_source_scope_id"), edge.source_scope_id);
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_destination_scope_id"), edge.destination_scope_id);
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_return_value_id"), edge.return_value_id);
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_return_abi"), edge.return_abi);
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_return_evaluation_order"), std.FormatInt(edge.return_evaluation_order));
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_cleanup_begin_order"), std.FormatInt(edge.cleanup_begin_order));
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_terminator_order"), std.FormatInt(edge.terminator_order));
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_source_location"), edge.source_location);
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_exited_scope_chain"), edge.exited_scope_chain);
        edge_index = edge_index + 1;
    }
    output = mir_early_exit_cleanup_append_field(output, "early_exit_cleanup_entry_count", std.FormatInt(mir_early_exit_cleanup_entry_count(plan, ctx)));
    mut entry_index := 0;
    while entry_index < mir_early_exit_cleanup_entry_count(plan, ctx) {
        mut entry := mir_early_exit_cleanup_entry_at(plan, entry_index, ctx);
        mut prefix := std.Concat("early_exit_cleanup_entry_", std.FormatInt(entry_index));
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_edge_id"), entry.edge_id);
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_scope_id"), entry.scope_id);
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_resource_id"), entry.resource_id);
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_cleanup_operation_id"), entry.cleanup_operation_id);
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_destructor_id"), entry.destructor_id);
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_owning_declaration"), entry.owning_declaration);
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_source_location"), entry.source_location);
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_scope_depth"), std.FormatInt(entry.scope_depth));
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_declaration_order"), std.FormatInt(entry.declaration_order));
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_execution_order"), std.FormatInt(entry.execution_order));
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_prior_state"), entry.prior_state);
        output = mir_early_exit_cleanup_append_field(output, std.Concat(prefix, "_observable_effect"), entry.observable_effect);
        entry_index = entry_index + 1;
    }
    return output;
}

func mir_early_exit_cleanup_witness(plan: MirEarlyExitCleanupPlan[ctx], ctx: &Arena) str {
    mut output := std.Clone(ctx, "early_return_cleanup_witness: accepted order_policy=inner_before_outer return_semantics=preserved aggregate_return=deferred_to_phase16\n");
    mut edge_index := 0;
    while edge_index < mir_early_exit_cleanup_edge_count(plan, ctx) {
        mut edge := mir_early_exit_cleanup_edge_at(plan, edge_index, ctx);
        output = std.Concat(output, std.Concat("early_return_cleanup_edge: id=", std.Concat(edge.edge_id, std.Concat(" kind=", std.Concat(edge.exit_kind, std.Concat(" exited_scopes=", std.Concat(edge.exited_scope_chain, std.Concat(" return_value=", std.Concat(edge.return_value_id, std.Concat(" return_abi=", std.Concat(edge.return_abi, "\n")))))))))));
        edge_index = edge_index + 1;
    }
    mut entry_index := 0;
    while entry_index < mir_early_exit_cleanup_entry_count(plan, ctx) {
        mut entry := mir_early_exit_cleanup_entry_at(plan, entry_index, ctx);
        output = std.Concat(output, std.Concat("early_return_cleanup: edge=", std.Concat(entry.edge_id, std.Concat(" scope=", std.Concat(entry.scope_id, std.Concat(" resource=", std.Concat(entry.resource_id, std.Concat(" order=", std.Concat(std.FormatInt(entry.execution_order), std.Concat(" destructor=", std.Concat(entry.destructor_id, std.Concat(" source=", std.Concat(entry.source_location, std.Concat(" effect=", std.Concat(entry.observable_effect, "\n")))))))))))))));
        entry_index = entry_index + 1;
    }
    return output;
}
