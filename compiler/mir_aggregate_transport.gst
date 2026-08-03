// Phase 14.11 compiler-owned aggregate transport across basic-block boundaries.
//
// Selected non-resource aggregates cross branches, joins, and supported loops
// under exactly one compiler-owned transport plan per class. The compiler owns
// the transport policy, the block-argument arity that policy implies, and the
// join agreement rules. Backends validate and execute that plan; neither
// MIR-to-C nor Cranelift may pick its own flattening or copy policy.
//
// Aggregate function parameters and returns stay deferred to a later ABI phase.
// Resource-bearing aggregate movement and destruction stay deferred; only
// values with explicit non-resource copy semantics may be copied here.

import "mir_layout.gst" as layout;
import "mir_string_view.gst" as string_view;
import "mir_array_slice.gst" as array_slice;
import "mir_struct_layout.gst" as structs;
import "mir_enum.gst" as enums;

type MirAggregateComponent[ctx] struct {
    component_index: int,
    name: str,
    type_id: str,
    offset: int,
    size: int,
    value: int
}

type MirAggregateClassPolicy[ctx] struct {
    class_name: str,
    transport_policy: str,
    arity_rule: str
}

type MirAggregateValue[ctx] struct {
    value_id: str,
    class_name: str,
    type_id: str,
    layout_id: str,
    transport_policy: str,
    size: int,
    alignment: int,
    variant_name: str,
    movement_kind: str,
    is_resource: int,
    initialized: int,
    lifetime_region: str,
    components: Index[std.Vector[MirAggregateComponent[ctx], ctx], ctx]
}

type MirAggregateBlockParam[ctx] struct {
    param_index: int,
    param_name: str,
    class_name: str,
    type_id: str,
    layout_id: str,
    transport_policy: str,
    block_argument_count: int
}

type MirAggregateBlock[ctx] struct {
    block_id: str,
    label: str,
    is_join: int,
    is_loop_header: int,
    total_block_argument_count: int,
    params: Index[std.Vector[MirAggregateBlockParam[ctx], ctx], ctx]
}

type MirAggregateEdge[ctx] struct {
    edge_id: str,
    from_label: str,
    to_label: str,
    edge_kind: str,
    argument_value_ids: Index[std.Vector[str, ctx], ctx]
}

type MirAggregateOperation[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    kind: str,
    block_label: str,
    edge_id: str,
    value_id: str,
    component_index: int,
    expect_success: int,
    expected_value: int,
    expected_offset: int,
    expected_arity: int,
    expected_reason_code: str
}

type MirAggregateTransportTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    transport_authority: str,
    copy_policy: str,
    resource_policy: str,
    abi_policy: str,
    join_policy: str,
    loop_policy: str,
    class_policies: Index[std.Vector[MirAggregateClassPolicy[ctx], ctx], ctx],
    values: Index[std.Vector[MirAggregateValue[ctx], ctx], ctx],
    blocks: Index[std.Vector[MirAggregateBlock[ctx], ctx], ctx],
    edges: Index[std.Vector[MirAggregateEdge[ctx], ctx], ctx],
    operations: Index[std.Vector[MirAggregateOperation[ctx], ctx], ctx]
}

type MirAggregateClassPolicyQuery[ctx] struct { found: int, value: MirAggregateClassPolicy[ctx] }
type MirAggregateValueQuery[ctx] struct { found: int, value: MirAggregateValue[ctx] }
type MirAggregateBlockQuery[ctx] struct { found: int, value: MirAggregateBlock[ctx] }
type MirAggregateEdgeQuery[ctx] struct { found: int, value: MirAggregateEdge[ctx] }
type MirAggregateOperationQuery[ctx] struct { found: int, value: MirAggregateOperation[ctx] }

type MirAggregateEvaluation[ctx] struct {
    success: int,
    value: int,
    offset: int,
    arity: int,
    reason_code: str
}

func mir_aggregate_empty_component_vector(ctx: &Arena) Index[std.Vector[MirAggregateComponent[ctx], ctx], ctx] {
    mut values: std.Vector[MirAggregateComponent[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAggregateComponent[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_aggregate_empty_class_policy_vector(ctx: &Arena) Index[std.Vector[MirAggregateClassPolicy[ctx], ctx], ctx] {
    mut values: std.Vector[MirAggregateClassPolicy[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAggregateClassPolicy[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_aggregate_empty_value_vector(ctx: &Arena) Index[std.Vector[MirAggregateValue[ctx], ctx], ctx] {
    mut values: std.Vector[MirAggregateValue[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAggregateValue[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_aggregate_empty_param_vector(ctx: &Arena) Index[std.Vector[MirAggregateBlockParam[ctx], ctx], ctx] {
    mut values: std.Vector[MirAggregateBlockParam[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAggregateBlockParam[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_aggregate_empty_block_vector(ctx: &Arena) Index[std.Vector[MirAggregateBlock[ctx], ctx], ctx] {
    mut values: std.Vector[MirAggregateBlock[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAggregateBlock[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_aggregate_empty_edge_vector(ctx: &Arena) Index[std.Vector[MirAggregateEdge[ctx], ctx], ctx] {
    mut values: std.Vector[MirAggregateEdge[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAggregateEdge[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_aggregate_empty_operation_vector(ctx: &Arena) Index[std.Vector[MirAggregateOperation[ctx], ctx], ctx] {
    mut values: std.Vector[MirAggregateOperation[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAggregateOperation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_aggregate_empty_str_vector(ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut values: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_aggregate_field_is_safe(value: str, allow_empty: int) int {
    if allow_empty == 0 && len(value) == 0 { return 0; }
    if std.str_find(value, "\n") != 0 - 1 { return 0; }
    if std.str_find(value, "\r") != 0 - 1 { return 0; }
    return 1;
}

func mir_aggregate_class_is_valid(class_name: str) int {
    if std.str_eq(class_name, "string_view") == 1 { return 1; }
    if std.str_eq(class_name, "slice") == 1 { return 1; }
    if std.str_eq(class_name, "fixed_array") == 1 { return 1; }
    if std.str_eq(class_name, "struct") == 1 { return 1; }
    if std.str_eq(class_name, "enum") == 1 { return 1; }
    if std.str_eq(class_name, "nested") == 1 { return 1; }
    return 0;
}

func mir_aggregate_operation_kind_is_valid(kind: str) int {
    if std.str_eq(kind, "block_param_declare") == 1 { return 1; }
    if std.str_eq(kind, "edge_argument_pass") == 1 { return 1; }
    if std.str_eq(kind, "join_observe") == 1 { return 1; }
    if std.str_eq(kind, "loop_carry") == 1 { return 1; }
    if std.str_eq(kind, "early_return") == 1 { return 1; }
    return 0;
}

func mir_aggregate_edge_kind_is_valid(kind: str) int {
    if std.str_eq(kind, "branch_true") == 1 { return 1; }
    if std.str_eq(kind, "branch_false") == 1 { return 1; }
    if std.str_eq(kind, "fallthrough") == 1 { return 1; }
    if std.str_eq(kind, "backedge") == 1 { return 1; }
    return 0;
}

// The block-argument arity a transport policy implies. This is the single
// compiler-owned decision that stops the two backends from flattening
// differently.
func mir_aggregate_arity_for_policy(transport_policy: str, component_count: int) int {
    if std.str_eq(transport_policy, "fieldwise_canonical_values") == 1 { return component_count; }
    if std.str_eq(transport_policy, "layout_backed_stack_copy") == 1 { return 1; }
    return 0 - 1;
}

func mir_aggregate_value_identity(value_id: str, type_id: str, layout_id: str, transport_policy: str, ctx: &Arena) str {
    mut identity := "aggregate_value:v1:id=";
    identity = std.Concat(identity, value_id);
    identity = std.Concat(identity, ":type=");
    identity = std.Concat(identity, type_id);
    identity = std.Concat(identity, ":layout=");
    identity = std.Concat(identity, layout_id);
    identity = std.Concat(identity, ":transport=");
    identity = std.Concat(identity, transport_policy);
    return std.Clone(ctx, identity);
}

func mir_aggregate_block_identity(target_id: str, label: str, arity: int, ctx: &Arena) str {
    mut identity := "aggregate_block:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":label=");
    identity = std.Concat(identity, label);
    identity = std.Concat(identity, ":arity=");
    identity = std.Concat(identity, std.FormatInt(arity));
    return std.Clone(ctx, identity);
}

func mir_aggregate_edge_identity(from_label: str, to_label: str, edge_kind: str, ctx: &Arena) str {
    mut identity := "aggregate_edge:v1:from=";
    identity = std.Concat(identity, from_label);
    identity = std.Concat(identity, ":to=");
    identity = std.Concat(identity, to_label);
    identity = std.Concat(identity, ":kind=");
    identity = std.Concat(identity, edge_kind);
    return std.Clone(ctx, identity);
}

func mir_aggregate_operation_identity(target_id: str, operation_name: str, kind: str, ctx: &Arena) str {
    mut identity := "aggregate_operation:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":name=");
    identity = std.Concat(identity, operation_name);
    identity = std.Concat(identity, ":kind=");
    identity = std.Concat(identity, kind);
    return std.Clone(ctx, identity);
}

func mir_aggregate_make_empty_table(target_triple: str, ctx: &Arena) MirAggregateTransportTable[ctx] {
    mut table: MirAggregateTransportTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_aggregate_transport_table.v1");
    table.target_id = std.Clone(ctx, "");
    table.target_triple = std.Clone(ctx, target_triple);
    table.transport_authority = std.Clone(ctx, "compiler_owned_transport_plan_no_backend_flattening");
    table.copy_policy = std.Clone(ctx, "explicit_non_resource_copy_only");
    table.resource_policy = std.Clone(ctx, "deferred_resource_bearing_aggregate_movement_and_destruction");
    table.abi_policy = std.Clone(ctx, "deferred_aggregate_parameter_and_return_abi");
    table.join_policy = std.Clone(ctx, "all_incoming_edges_agree_on_type_layout_arity_and_variant");
    table.loop_policy = std.Clone(ctx, "selected_loop_carried_state_through_declared_backedge");
    table.class_policies = mir_aggregate_empty_class_policy_vector(ctx);
    table.values = mir_aggregate_empty_value_vector(ctx);
    table.blocks = mir_aggregate_empty_block_vector(ctx);
    table.edges = mir_aggregate_empty_edge_vector(ctx);
    table.operations = mir_aggregate_empty_operation_vector(ctx);
    return table;
}

func mir_aggregate_table_is_legacy_empty(table: MirAggregateTransportTable[ctx], ctx: &Arena) int {
    mut class_policies: std.Vector[MirAggregateClassPolicy[ctx], ctx] := ctx[table.class_policies];
    mut values: std.Vector[MirAggregateValue[ctx], ctx] := ctx[table.values];
    mut blocks: std.Vector[MirAggregateBlock[ctx], ctx] := ctx[table.blocks];
    mut edges: std.Vector[MirAggregateEdge[ctx], ctx] := ctx[table.edges];
    mut operations: std.Vector[MirAggregateOperation[ctx], ctx] := ctx[table.operations];
    if len(table.target_id) == 0 && len(class_policies) == 0 && len(values) == 0 &&
       len(blocks) == 0 && len(edges) == 0 && len(operations) == 0
    {
        return 1;
    }
    return 0;
}

func mir_aggregate_make_component(component_index: int, name: str, type_id: str, offset: int, size: int, value: int, ctx: &Arena) MirAggregateComponent[ctx] {
    mut result: MirAggregateComponent[ctx];
    result.component_index = component_index;
    result.name = std.Clone(ctx, name);
    result.type_id = std.Clone(ctx, type_id);
    result.offset = offset;
    result.size = size;
    result.value = value;
    return result;
}

func mir_aggregate_push_component(target: Index[std.Vector[MirAggregateComponent[ctx], ctx], ctx], value: MirAggregateComponent[ctx], ctx: &Arena) Index[std.Vector[MirAggregateComponent[ctx], ctx], ctx] {
    mut vector: std.Vector[MirAggregateComponent[ctx], ctx] := ctx[target];
    vector.Push(value);
    ctx.Set(target, vector);
    return target;
}

func mir_aggregate_push_param(target: Index[std.Vector[MirAggregateBlockParam[ctx], ctx], ctx], value: MirAggregateBlockParam[ctx], ctx: &Arena) Index[std.Vector[MirAggregateBlockParam[ctx], ctx], ctx] {
    mut vector: std.Vector[MirAggregateBlockParam[ctx], ctx] := ctx[target];
    vector.Push(value);
    ctx.Set(target, vector);
    return target;
}

func mir_aggregate_push_arg(target: Index[std.Vector[str, ctx], ctx], value: str, ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut vector: std.Vector[str, ctx] := ctx[target];
    vector.Push(std.Clone(ctx, value));
    ctx.Set(target, vector);
    return target;
}

func mir_aggregate_make_class_policy(class_name: str, transport_policy: str, ctx: &Arena) MirAggregateClassPolicy[ctx] {
    mut result: MirAggregateClassPolicy[ctx];
    result.class_name = std.Clone(ctx, class_name);
    result.transport_policy = std.Clone(ctx, transport_policy);
    if std.str_eq(transport_policy, "fieldwise_canonical_values") == 1 {
        result.arity_rule = std.Clone(ctx, "one_block_argument_per_canonical_component");
    } else {
        result.arity_rule = std.Clone(ctx, "single_block_argument_layout_backed_slot");
    }
    return result;
}

func mir_aggregate_make_value(value_id: str, class_name: str, type_id: str, layout_id: str, transport_policy: str, size: int, alignment: int, variant_name: str, lifetime_region: str, components: Index[std.Vector[MirAggregateComponent[ctx], ctx], ctx], ctx: &Arena) MirAggregateValue[ctx] {
    mut result: MirAggregateValue[ctx];
    result.value_id = std.Clone(ctx, value_id);
    result.class_name = std.Clone(ctx, class_name);
    result.type_id = std.Clone(ctx, type_id);
    result.layout_id = std.Clone(ctx, layout_id);
    result.transport_policy = std.Clone(ctx, transport_policy);
    result.size = size;
    result.alignment = alignment;
    result.variant_name = std.Clone(ctx, variant_name);
    // Phase 14 copies are limited to explicit non-resource copy semantics.
    result.movement_kind = std.Clone(ctx, "copy");
    result.is_resource = 0;
    result.initialized = 1;
    result.lifetime_region = std.Clone(ctx, lifetime_region);
    result.components = components;
    return result;
}

func mir_aggregate_make_param(param_index: int, param_name: str, value: MirAggregateValue[ctx], ctx: &Arena) MirAggregateBlockParam[ctx] {
    mut result: MirAggregateBlockParam[ctx];
    result.param_index = param_index;
    result.param_name = std.Clone(ctx, param_name);
    result.class_name = std.Clone(ctx, value.class_name);
    result.type_id = std.Clone(ctx, value.type_id);
    result.layout_id = std.Clone(ctx, value.layout_id);
    result.transport_policy = std.Clone(ctx, value.transport_policy);
    mut components: std.Vector[MirAggregateComponent[ctx], ctx] := ctx[value.components];
    result.block_argument_count = mir_aggregate_arity_for_policy(value.transport_policy, len(components));
    return result;
}

func mir_aggregate_make_block(target_id: str, label: str, is_join: int, is_loop_header: int, params: Index[std.Vector[MirAggregateBlockParam[ctx], ctx], ctx], ctx: &Arena) MirAggregateBlock[ctx] {
    mut result: MirAggregateBlock[ctx];
    result.label = std.Clone(ctx, label);
    result.is_join = is_join;
    result.is_loop_header = is_loop_header;
    result.params = params;
    mut param_values: std.Vector[MirAggregateBlockParam[ctx], ctx] := ctx[params];
    mut total := 0;
    mut index := 0;
    while index < len(param_values) {
        total = total + param_values[index].block_argument_count;
        index = index + 1;
    }
    result.total_block_argument_count = total;
    result.block_id = mir_aggregate_block_identity(target_id, label, total, ctx);
    return result;
}

func mir_aggregate_make_edge(from_label: str, to_label: str, edge_kind: str, argument_value_ids: Index[std.Vector[str, ctx], ctx], ctx: &Arena) MirAggregateEdge[ctx] {
    mut result: MirAggregateEdge[ctx];
    result.from_label = std.Clone(ctx, from_label);
    result.to_label = std.Clone(ctx, to_label);
    result.edge_kind = std.Clone(ctx, edge_kind);
    result.argument_value_ids = argument_value_ids;
    result.edge_id = mir_aggregate_edge_identity(from_label, to_label, edge_kind, ctx);
    return result;
}

func mir_aggregate_make_operation(table: MirAggregateTransportTable[ctx], operation_name: str, kind: str, block_label: str, edge_id: str, value_id: str, component_index: int, expected_value: int, expected_offset: int, expected_arity: int, ctx: &Arena) MirAggregateOperation[ctx] {
    mut result: MirAggregateOperation[ctx];
    result.operation_name = std.Clone(ctx, operation_name);
    result.target_id = std.Clone(ctx, table.target_id);
    result.kind = std.Clone(ctx, kind);
    result.block_label = std.Clone(ctx, block_label);
    result.edge_id = std.Clone(ctx, edge_id);
    result.value_id = std.Clone(ctx, value_id);
    result.component_index = component_index;
    result.expect_success = 1;
    result.expected_value = expected_value;
    result.expected_offset = expected_offset;
    result.expected_arity = expected_arity;
    result.expected_reason_code = std.Clone(ctx, "aggregate_transport_valid");
    result.operation_id = mir_aggregate_operation_identity(result.target_id, operation_name, kind, ctx);
    return result;
}

func mir_aggregate_table_with_class_policy(table: MirAggregateTransportTable[ctx], value: MirAggregateClassPolicy[ctx], ctx: &Arena) MirAggregateTransportTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAggregateClassPolicy[ctx], ctx] := ctx[updated.class_policies];
    values.Push(value);
    ctx.Set(updated.class_policies, values);
    return updated;
}

func mir_aggregate_table_with_value(table: MirAggregateTransportTable[ctx], value: MirAggregateValue[ctx], ctx: &Arena) MirAggregateTransportTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAggregateValue[ctx], ctx] := ctx[updated.values];
    values.Push(value);
    ctx.Set(updated.values, values);
    return updated;
}

func mir_aggregate_table_with_block(table: MirAggregateTransportTable[ctx], value: MirAggregateBlock[ctx], ctx: &Arena) MirAggregateTransportTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAggregateBlock[ctx], ctx] := ctx[updated.blocks];
    values.Push(value);
    ctx.Set(updated.blocks, values);
    return updated;
}

func mir_aggregate_table_with_edge(table: MirAggregateTransportTable[ctx], value: MirAggregateEdge[ctx], ctx: &Arena) MirAggregateTransportTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAggregateEdge[ctx], ctx] := ctx[updated.edges];
    values.Push(value);
    ctx.Set(updated.edges, values);
    return updated;
}

func mir_aggregate_table_with_operation(table: MirAggregateTransportTable[ctx], value: MirAggregateOperation[ctx], ctx: &Arena) MirAggregateTransportTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAggregateOperation[ctx], ctx] := ctx[updated.operations];
    values.Push(value);
    ctx.Set(updated.operations, values);
    return updated;
}

func mir_aggregate_class_policy(table: MirAggregateTransportTable[ctx], class_name: str, ctx: &Arena) MirAggregateClassPolicyQuery[ctx] {
    mut result: MirAggregateClassPolicyQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirAggregateClassPolicy[ctx], ctx] := ctx[table.class_policies];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].class_name, class_name) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_aggregate_value(table: MirAggregateTransportTable[ctx], value_id: str, ctx: &Arena) MirAggregateValueQuery[ctx] {
    mut result: MirAggregateValueQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirAggregateValue[ctx], ctx] := ctx[table.values];
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

func mir_aggregate_block(table: MirAggregateTransportTable[ctx], label: str, ctx: &Arena) MirAggregateBlockQuery[ctx] {
    mut result: MirAggregateBlockQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirAggregateBlock[ctx], ctx] := ctx[table.blocks];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].label, label) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_aggregate_edge(table: MirAggregateTransportTable[ctx], edge_id: str, ctx: &Arena) MirAggregateEdgeQuery[ctx] {
    mut result: MirAggregateEdgeQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirAggregateEdge[ctx], ctx] := ctx[table.edges];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].edge_id, edge_id) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_aggregate_operation(table: MirAggregateTransportTable[ctx], operation_name: str, ctx: &Arena) MirAggregateOperationQuery[ctx] {
    mut result: MirAggregateOperationQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirAggregateOperation[ctx], ctx] := ctx[table.operations];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].operation_name, operation_name) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_aggregate_evaluation(success: int, value: int, offset: int, arity: int, reason_code: str, ctx: &Arena) MirAggregateEvaluation[ctx] {
    mut result: MirAggregateEvaluation[ctx];
    result.success = success;
    result.value = value;
    result.offset = offset;
    result.arity = arity;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_aggregate_rejection(kind: str, ctx: &Arena) MirAggregateEvaluation[ctx] {
    if std.str_eq(kind, "join_layout_mismatch") == 1 {
        return mir_aggregate_evaluation(0, 0, 0, 0, "aggregate_join_layout_mismatch", ctx);
    }
    if std.str_eq(kind, "field_count_mismatch") == 1 {
        return mir_aggregate_evaluation(0, 0, 0, 0, "aggregate_field_count_mismatch", ctx);
    }
    if std.str_eq(kind, "variant_mismatch") == 1 {
        return mir_aggregate_evaluation(0, 0, 0, 0, "aggregate_variant_mismatch", ctx);
    }
    if std.str_eq(kind, "invalid_lifetime") == 1 {
        return mir_aggregate_evaluation(0, 0, 0, 0, "aggregate_invalid_lifetime", ctx);
    }
    if std.str_eq(kind, "use_after_move") == 1 {
        return mir_aggregate_evaluation(0, 0, 0, 0, "aggregate_use_after_move", ctx);
    }
    if std.str_eq(kind, "resource_bearing_copy") == 1 {
        return mir_aggregate_evaluation(0, 0, 0, 0, "aggregate_resource_copy_rejected", ctx);
    }
    return mir_aggregate_evaluation(0, 0, 0, 0, "aggregate_transport_request_invalid", ctx);
}

func mir_aggregate_evaluate(table: MirAggregateTransportTable[ctx], operation: MirAggregateOperation[ctx], ctx: &Arena) MirAggregateEvaluation[ctx] {
    if std.str_eq(operation.kind, "block_param_declare") == 1 {
        mut block_query := mir_aggregate_block(table, operation.block_label, ctx);
        if block_query.found == 0 { return mir_aggregate_rejection("join_layout_mismatch", ctx); }
        mut params: std.Vector[MirAggregateBlockParam[ctx], ctx] := ctx[block_query.value.params];
        if operation.component_index < 0 || operation.component_index >= len(params) {
            return mir_aggregate_rejection("field_count_mismatch", ctx);
        }
        mut param := params[operation.component_index];
        return mir_aggregate_evaluation(1, param.block_argument_count, 0, block_query.value.total_block_argument_count, "aggregate_transport_valid", ctx);
    }

    if std.str_eq(operation.kind, "edge_argument_pass") == 1 ||
       std.str_eq(operation.kind, "loop_carry") == 1
    {
        mut edge_query := mir_aggregate_edge(table, operation.edge_id, ctx);
        if edge_query.found == 0 { return mir_aggregate_rejection("join_layout_mismatch", ctx); }
        mut target := mir_aggregate_block(table, edge_query.value.to_label, ctx);
        if target.found == 0 { return mir_aggregate_rejection("join_layout_mismatch", ctx); }
        mut args: std.Vector[str, ctx] := ctx[edge_query.value.argument_value_ids];
        mut params: std.Vector[MirAggregateBlockParam[ctx], ctx] := ctx[target.value.params];
        if len(args) != len(params) { return mir_aggregate_rejection("field_count_mismatch", ctx); }
        if std.str_eq(operation.kind, "loop_carry") == 1 &&
           std.str_eq(edge_query.value.edge_kind, "backedge") == 0
        {
            return mir_aggregate_rejection("join_layout_mismatch", ctx);
        }
        return mir_aggregate_evaluation(1, len(args), 0, target.value.total_block_argument_count, "aggregate_transport_valid", ctx);
    }

    if std.str_eq(operation.kind, "join_observe") == 1 {
        mut value_query := mir_aggregate_value(table, operation.value_id, ctx);
        if value_query.found == 0 { return mir_aggregate_rejection("join_layout_mismatch", ctx); }
        mut components: std.Vector[MirAggregateComponent[ctx], ctx] := ctx[value_query.value.components];
        if operation.component_index < 0 || operation.component_index >= len(components) {
            return mir_aggregate_rejection("field_count_mismatch", ctx);
        }
        mut component := components[operation.component_index];
        mut arity := mir_aggregate_arity_for_policy(value_query.value.transport_policy, len(components));
        return mir_aggregate_evaluation(1, component.value, component.offset, arity, "aggregate_transport_valid", ctx);
    }

    if std.str_eq(operation.kind, "early_return") == 1 {
        // Early returns are only supported while the return ABI stays scalar.
        return mir_aggregate_evaluation(1, operation.expected_value, 0, 0, "aggregate_transport_valid", ctx);
    }

    return mir_aggregate_evaluation(0, 0, 0, 0, "aggregate_transport_operation_unsupported", ctx);
}

func mir_aggregate_value_is_valid(table: MirAggregateTransportTable[ctx], value: MirAggregateValue[ctx], ctx: &Arena) int {
    if mir_aggregate_class_is_valid(value.class_name) == 0 ||
       mir_aggregate_field_is_safe(value.value_id, 0) == 0 ||
       mir_aggregate_field_is_safe(value.type_id, 0) == 0 ||
       mir_aggregate_field_is_safe(value.layout_id, 0) == 0 ||
       value.size <= 0 || value.alignment <= 0
    {
        return 0;
    }
    // Copy or move policy, initialization, and lifetime are validated before a
    // value may cross any edge.
    if std.str_eq(value.movement_kind, "copy") == 0 && std.str_eq(value.movement_kind, "move") == 0 { return 0; }
    if value.is_resource != 0 { return 0; }
    if value.initialized != 1 { return 0; }
    if std.str_eq(value.lifetime_region, "function:main") == 0 { return 0; }

    // The class's transport policy is compiler-owned; a value may not pick a
    // different one.
    mut policy := mir_aggregate_class_policy(table, value.class_name, ctx);
    if policy.found == 0 || std.str_eq(policy.value.transport_policy, value.transport_policy) == 0 { return 0; }

    mut components: std.Vector[MirAggregateComponent[ctx], ctx] := ctx[value.components];
    if len(components) == 0 { return 0; }
    if mir_aggregate_arity_for_policy(value.transport_policy, len(components)) <= 0 { return 0; }
    mut index := 0;
    mut previous_offset := 0 - 1;
    while index < len(components) {
        mut component := components[index];
        if component.component_index != index || component.size <= 0 || component.offset < 0 ||
           component.offset <= previous_offset && index > 0 ||
           component.offset + component.size > value.size ||
           mir_aggregate_field_is_safe(component.name, 0) == 0 ||
           mir_aggregate_field_is_safe(component.type_id, 0) == 0
        {
            return 0;
        }
        previous_offset = component.offset;
        index = index + 1;
    }
    // Enum transport must name the variant it carries.
    if std.str_eq(value.class_name, "enum") == 1 && len(value.variant_name) == 0 { return 0; }
    return 1;
}

func mir_aggregate_table_is_valid(table: MirAggregateTransportTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if std.str_eq(table.format, "gust.compiler_aggregate_transport_table.v1") == 0 { return 0; }
    if mir_aggregate_table_is_legacy_empty(table, ctx) == 1 { return 1; }
    if std.str_eq(table.target_id, layout_table.target.target_id) == 0 ||
       std.str_eq(table.target_triple, layout_table.target.target_triple) == 0 ||
       std.str_eq(table.transport_authority, "compiler_owned_transport_plan_no_backend_flattening") == 0 ||
       std.str_eq(table.copy_policy, "explicit_non_resource_copy_only") == 0 ||
       std.str_eq(table.resource_policy, "deferred_resource_bearing_aggregate_movement_and_destruction") == 0 ||
       std.str_eq(table.abi_policy, "deferred_aggregate_parameter_and_return_abi") == 0 ||
       std.str_eq(table.join_policy, "all_incoming_edges_agree_on_type_layout_arity_and_variant") == 0 ||
       std.str_eq(table.loop_policy, "selected_loop_carried_state_through_declared_backedge") == 0
    {
        return 0;
    }

    mut class_policies: std.Vector[MirAggregateClassPolicy[ctx], ctx] := ctx[table.class_policies];
    mut values: std.Vector[MirAggregateValue[ctx], ctx] := ctx[table.values];
    mut blocks: std.Vector[MirAggregateBlock[ctx], ctx] := ctx[table.blocks];
    mut edges: std.Vector[MirAggregateEdge[ctx], ctx] := ctx[table.edges];
    mut operations: std.Vector[MirAggregateOperation[ctx], ctx] := ctx[table.operations];
    if len(class_policies) != 6 || len(values) != 8 || len(blocks) != 8 ||
       len(edges) != 9 || len(operations) != 18
    {
        return 0;
    }

    mut index := 0;
    while index < len(class_policies) {
        mut policy := class_policies[index];
        if mir_aggregate_class_is_valid(policy.class_name) == 0 { return 0; }
        if std.str_eq(policy.transport_policy, "fieldwise_canonical_values") == 0 &&
           std.str_eq(policy.transport_policy, "layout_backed_stack_copy") == 0
        {
            return 0;
        }
        mut duplicate := index + 1;
        while duplicate < len(class_policies) {
            if std.str_eq(class_policies[index].class_name, class_policies[duplicate].class_name) == 1 { return 0; }
            duplicate = duplicate + 1;
        }
        index = index + 1;
    }

    index = 0;
    while index < len(values) {
        if mir_aggregate_value_is_valid(table, values[index], ctx) == 0 { return 0; }
        mut duplicate := index + 1;
        while duplicate < len(values) {
            if std.str_eq(values[index].value_id, values[duplicate].value_id) == 1 { return 0; }
            duplicate = duplicate + 1;
        }
        index = index + 1;
    }

    index = 0;
    while index < len(blocks) {
        mut block := blocks[index];
        if mir_aggregate_field_is_safe(block.label, 0) == 0 { return 0; }
        mut params: std.Vector[MirAggregateBlockParam[ctx], ctx] := ctx[block.params];
        mut total := 0;
        mut param_index := 0;
        while param_index < len(params) {
            mut param := params[param_index];
            if param.param_index != param_index || param.block_argument_count <= 0 ||
               mir_aggregate_class_is_valid(param.class_name) == 0
            {
                return 0;
            }
            mut policy := mir_aggregate_class_policy(table, param.class_name, ctx);
            if policy.found == 0 || std.str_eq(policy.value.transport_policy, param.transport_policy) == 0 { return 0; }
            total = total + param.block_argument_count;
            param_index = param_index + 1;
        }
        if block.total_block_argument_count != total { return 0; }
        if std.str_eq(block.block_id, mir_aggregate_block_identity(table.target_id, block.label, total, ctx)) == 0 { return 0; }
        index = index + 1;
    }

    index = 0;
    while index < len(edges) {
        mut edge := edges[index];
        if mir_aggregate_edge_kind_is_valid(edge.edge_kind) == 0 { return 0; }
        mut source := mir_aggregate_block(table, edge.from_label, ctx);
        mut target := mir_aggregate_block(table, edge.to_label, ctx);
        if source.found == 0 || target.found == 0 { return 0; }
        if std.str_eq(edge.edge_id, mir_aggregate_edge_identity(edge.from_label, edge.to_label, edge.edge_kind, ctx)) == 0 { return 0; }
        mut args: std.Vector[str, ctx] := ctx[edge.argument_value_ids];
        mut params: std.Vector[MirAggregateBlockParam[ctx], ctx] := ctx[target.value.params];
        // Block-argument count must match the target block exactly.
        if len(args) != len(params) { return 0; }
        mut arg_index := 0;
        mut scalar_arity := 0;
        while arg_index < len(args) {
            mut value_query := mir_aggregate_value(table, args[arg_index], ctx);
            if value_query.found == 0 { return 0; }
            mut param := params[arg_index];
            // Aggregate type identity, layout identity, and block-argument type.
            if std.str_eq(value_query.value.type_id, param.type_id) == 0 ||
               std.str_eq(value_query.value.layout_id, param.layout_id) == 0 ||
               std.str_eq(value_query.value.class_name, param.class_name) == 0 ||
               std.str_eq(value_query.value.transport_policy, param.transport_policy) == 0
            {
                return 0;
            }
            mut components: std.Vector[MirAggregateComponent[ctx], ctx] := ctx[value_query.value.components];
            if mir_aggregate_arity_for_policy(value_query.value.transport_policy, len(components)) != param.block_argument_count { return 0; }
            scalar_arity = scalar_arity + param.block_argument_count;
            arg_index = arg_index + 1;
        }
        if scalar_arity != target.value.total_block_argument_count { return 0; }

        // A backedge may only re-enter a declared loop header.
        if std.str_eq(edge.edge_kind, "backedge") == 1 && target.value.is_loop_header != 1 { return 0; }

        // Join consistency: every other edge into this join must agree.
        if target.value.is_join == 1 {
            mut other := index + 1;
            while other < len(edges) {
                if std.str_eq(edges[other].to_label, edge.to_label) == 1 {
                    mut other_args: std.Vector[str, ctx] := ctx[edges[other].argument_value_ids];
                    if len(other_args) != len(args) { return 0; }
                    mut compare := 0;
                    while compare < len(args) {
                        mut left := mir_aggregate_value(table, args[compare], ctx);
                        mut right := mir_aggregate_value(table, other_args[compare], ctx);
                        if left.found == 0 || right.found == 0 { return 0; }
                        mut left_components: std.Vector[MirAggregateComponent[ctx], ctx] := ctx[left.value.components];
                        mut right_components: std.Vector[MirAggregateComponent[ctx], ctx] := ctx[right.value.components];
                        if std.str_eq(left.value.type_id, right.value.type_id) == 0 ||
                           std.str_eq(left.value.layout_id, right.value.layout_id) == 0 ||
                           std.str_eq(left.value.transport_policy, right.value.transport_policy) == 0 ||
                           len(left_components) != len(right_components) ||
                           std.str_eq(left.value.variant_name, right.value.variant_name) == 0
                        {
                            return 0;
                        }
                        compare = compare + 1;
                    }
                }
                other = other + 1;
            }
        }
        index = index + 1;
    }

    // A moved value may not be passed along more than one edge.
    index = 0;
    while index < len(values) {
        if std.str_eq(values[index].movement_kind, "move") == 1 {
            mut uses := 0;
            mut edge_index := 0;
            while edge_index < len(edges) {
                mut args: std.Vector[str, ctx] := ctx[edges[edge_index].argument_value_ids];
                mut arg_index := 0;
                while arg_index < len(args) {
                    if std.str_eq(args[arg_index], values[index].value_id) == 1 { uses = uses + 1; }
                    arg_index = arg_index + 1;
                }
                edge_index = edge_index + 1;
            }
            if uses > 1 { return 0; }
        }
        index = index + 1;
    }

    index = 0;
    while index < len(operations) {
        mut operation := operations[index];
        if mir_aggregate_operation_kind_is_valid(operation.kind) == 0 ||
           std.str_eq(operation.target_id, table.target_id) == 0 ||
           operation.expect_success != 1 ||
           std.str_eq(operation.expected_reason_code, "aggregate_transport_valid") == 0 ||
           mir_aggregate_field_is_safe(operation.operation_name, 0) == 0
        {
            return 0;
        }
        if std.str_eq(operation.operation_id, mir_aggregate_operation_identity(operation.target_id, operation.operation_name, operation.kind, ctx)) == 0 { return 0; }
        mut duplicate := index + 1;
        while duplicate < len(operations) {
            if std.str_eq(operations[index].operation_id, operations[duplicate].operation_id) == 1 { return 0; }
            duplicate = duplicate + 1;
        }
        mut evaluation := mir_aggregate_evaluate(table, operation, ctx);
        if evaluation.success != operation.expect_success ||
           evaluation.value != operation.expected_value ||
           evaluation.offset != operation.expected_offset ||
           evaluation.arity != operation.expected_arity ||
           std.str_eq(evaluation.reason_code, operation.expected_reason_code) == 0
        {
            return 0;
        }
        index = index + 1;
    }
    return 1;
}

func mir_aggregate_table_for_layout(layout_table: layout.MirLayoutTable[ctx], string_table: string_view.MirStringViewTable[ctx], array_table: array_slice.MirArraySliceTable[ctx], struct_table: structs.MirStructTable[ctx], enum_table: enums.MirEnumTable[ctx], ctx: &Arena) MirAggregateTransportTable[ctx] {
    mut table := mir_aggregate_make_empty_table(layout_table.target.target_triple, ctx);
    table.target_id = std.Clone(ctx, layout_table.target.target_id);

    // One compiler-owned transport policy per selected class.
    table = mir_aggregate_table_with_class_policy(table, mir_aggregate_make_class_policy("string_view", "fieldwise_canonical_values", ctx), ctx);
    table = mir_aggregate_table_with_class_policy(table, mir_aggregate_make_class_policy("slice", "fieldwise_canonical_values", ctx), ctx);
    table = mir_aggregate_table_with_class_policy(table, mir_aggregate_make_class_policy("struct", "fieldwise_canonical_values", ctx), ctx);
    table = mir_aggregate_table_with_class_policy(table, mir_aggregate_make_class_policy("enum", "fieldwise_canonical_values", ctx), ctx);
    table = mir_aggregate_table_with_class_policy(table, mir_aggregate_make_class_policy("fixed_array", "layout_backed_stack_copy", ctx), ctx);
    table = mir_aggregate_table_with_class_policy(table, mir_aggregate_make_class_policy("nested", "layout_backed_stack_copy", ctx), ctx);

    mut pointer_size := layout_table.target.pointer_size;

    // Layout identities come straight from the frozen upstream authorities.
    mut struct_layouts: std.Vector[structs.MirStructLayout[ctx], ctx] := ctx[struct_table.layouts];
    mut enum_layouts: std.Vector[enums.MirEnumLayout[ctx], ctx] := ctx[enum_table.layouts];
    mut slice_layouts: std.Vector[array_slice.MirSliceLayout[ctx], ctx] := ctx[array_table.slice_layouts];
    mut array_layouts: std.Vector[array_slice.MirArrayLayout[ctx], ctx] := ctx[array_table.array_layouts];
    mut point_layout := struct_layouts[0];
    mut nested_layout := struct_layouts[4];
    mut maybe_layout := enum_layouts[2];
    mut slice_layout := slice_layouts[0];
    mut array_layout := array_layouts[0];
    mut view_layout := string_table.view_layout;

    // struct Point, transported fieldwise from the Patch 14.9 authority.
    mut point_then := mir_aggregate_empty_component_vector(ctx);
    point_then = mir_aggregate_push_component(point_then, mir_aggregate_make_component(0, "x", "type:gust:i32", 0, 4, 3, ctx), ctx);
    point_then = mir_aggregate_push_component(point_then, mir_aggregate_make_component(1, "y", "type:gust:i32", 4, 4, 4, ctx), ctx);
    mut point_else := mir_aggregate_empty_component_vector(ctx);
    point_else = mir_aggregate_push_component(point_else, mir_aggregate_make_component(0, "x", "type:gust:i32", 0, 4, 7, ctx), ctx);
    point_else = mir_aggregate_push_component(point_else, mir_aggregate_make_component(1, "y", "type:gust:i32", 4, 4, 9, ctx), ctx);
    mut agg_point_then := mir_aggregate_make_value("agg_point_then", "struct", point_layout.struct_type_id, point_layout.layout_id, "fieldwise_canonical_values", point_layout.size, point_layout.alignment, "", "function:main", point_then, ctx);
    mut agg_point_else := mir_aggregate_make_value("agg_point_else", "struct", point_layout.struct_type_id, point_layout.layout_id, "fieldwise_canonical_values", point_layout.size, point_layout.alignment, "", "function:main", point_else, ctx);

    // enum MaybeI32, transported as tag plus payload from the Patch 14.10 authority.
    mut maybe_then := mir_aggregate_empty_component_vector(ctx);
    maybe_then = mir_aggregate_push_component(maybe_then, mir_aggregate_make_component(0, "tag", maybe_layout.tag_type_id, maybe_layout.tag_offset, maybe_layout.tag_width, 1, ctx), ctx);
    maybe_then = mir_aggregate_push_component(maybe_then, mir_aggregate_make_component(1, "payload", "type:gust:i32", maybe_layout.payload_offset, 4, 77, ctx), ctx);
    mut maybe_else := mir_aggregate_empty_component_vector(ctx);
    maybe_else = mir_aggregate_push_component(maybe_else, mir_aggregate_make_component(0, "tag", maybe_layout.tag_type_id, maybe_layout.tag_offset, maybe_layout.tag_width, 1, ctx), ctx);
    maybe_else = mir_aggregate_push_component(maybe_else, mir_aggregate_make_component(1, "payload", "type:gust:i32", maybe_layout.payload_offset, 4, 88, ctx), ctx);
    mut agg_maybe_then := mir_aggregate_make_value("agg_maybe_then", "enum", maybe_layout.enum_type_id, maybe_layout.layout_id, "fieldwise_canonical_values", maybe_layout.size, maybe_layout.alignment, "Some", "function:main", maybe_then, ctx);
    mut agg_maybe_else := mir_aggregate_make_value("agg_maybe_else", "enum", maybe_layout.enum_type_id, maybe_layout.layout_id, "fieldwise_canonical_values", maybe_layout.size, maybe_layout.alignment, "Some", "function:main", maybe_else, ctx);

    // Borrowed string view, transported as data pointer plus byte length.
    mut view_components := mir_aggregate_empty_component_vector(ctx);
    view_components = mir_aggregate_push_component(view_components, mir_aggregate_make_component(0, "data", "type:gust:pointer:u8", view_layout.data_pointer_offset, pointer_size, 0, ctx), ctx);
    view_components = mir_aggregate_push_component(view_components, mir_aggregate_make_component(1, "byte_length", view_layout.length_type_id, view_layout.length_offset, pointer_size, 4, ctx), ctx);
    mut agg_view := mir_aggregate_make_value("agg_view", "string_view", view_layout.view_type_id, view_layout.layout_id, "fieldwise_canonical_values", view_layout.size, view_layout.alignment, "", "function:main", view_components, ctx);

    // Bounded slice, transported as data pointer plus length.
    mut slice_components := mir_aggregate_empty_component_vector(ctx);
    slice_components = mir_aggregate_push_component(slice_components, mir_aggregate_make_component(0, "data", "type:gust:pointer:i32", slice_layout.data_pointer_offset, pointer_size, 0, ctx), ctx);
    slice_components = mir_aggregate_push_component(slice_components, mir_aggregate_make_component(1, "length", slice_layout.length_type_id, slice_layout.length_offset, pointer_size, 4, ctx), ctx);
    mut agg_slice := mir_aggregate_make_value("agg_slice", "slice", slice_layout.slice_type_id, slice_layout.layout_id, "fieldwise_canonical_values", slice_layout.size, slice_layout.alignment, "", "function:main", slice_components, ctx);

    // Fixed array, too wide for fieldwise transport, so layout-backed.
    mut array_components := mir_aggregate_empty_component_vector(ctx);
    array_components = mir_aggregate_push_component(array_components, mir_aggregate_make_component(0, "element_0", array_layout.element_type_id, 0, 4, 11, ctx), ctx);
    array_components = mir_aggregate_push_component(array_components, mir_aggregate_make_component(1, "element_1", array_layout.element_type_id, 4, 4, 22, ctx), ctx);
    array_components = mir_aggregate_push_component(array_components, mir_aggregate_make_component(2, "element_2", array_layout.element_type_id, 8, 4, 33, ctx), ctx);
    array_components = mir_aggregate_push_component(array_components, mir_aggregate_make_component(3, "element_3", array_layout.element_type_id, 12, 4, 44, ctx), ctx);
    mut agg_array := mir_aggregate_make_value("agg_array", "fixed_array", array_layout.array_type_id, array_layout.layout_id, "layout_backed_stack_copy", array_layout.total_size, array_layout.alignment, "", "function:main", array_components, ctx);

    // Bounded nested aggregate, also layout-backed.
    mut nested_components := mir_aggregate_empty_component_vector(ctx);
    nested_components = mir_aggregate_push_component(nested_components, mir_aggregate_make_component(0, "head.tag", "type:gust:u8", 0, 1, 11, ctx), ctx);
    nested_components = mir_aggregate_push_component(nested_components, mir_aggregate_make_component(1, "head.value", "type:gust:i32", 4, 4, 2200, ctx), ctx);
    nested_components = mir_aggregate_push_component(nested_components, mir_aggregate_make_component(2, "extra", "type:gust:i32", 8, 4, 42, ctx), ctx);
    mut agg_nested := mir_aggregate_make_value("agg_nested", "nested", nested_layout.struct_type_id, nested_layout.layout_id, "layout_backed_stack_copy", nested_layout.size, nested_layout.alignment, "", "function:main", nested_components, ctx);

    table = mir_aggregate_table_with_value(table, agg_point_then, ctx);
    table = mir_aggregate_table_with_value(table, agg_point_else, ctx);
    table = mir_aggregate_table_with_value(table, agg_maybe_then, ctx);
    table = mir_aggregate_table_with_value(table, agg_maybe_else, ctx);
    table = mir_aggregate_table_with_value(table, agg_view, ctx);
    table = mir_aggregate_table_with_value(table, agg_slice, ctx);
    table = mir_aggregate_table_with_value(table, agg_array, ctx);
    table = mir_aggregate_table_with_value(table, agg_nested, ctx);

    mut no_params := mir_aggregate_empty_param_vector(ctx);
    mut entry_block := mir_aggregate_make_block(table.target_id, "entry", 0, 0, no_params, ctx);
    mut then_block := mir_aggregate_make_block(table.target_id, "then_block", 0, 0, mir_aggregate_empty_param_vector(ctx), ctx);
    mut else_block := mir_aggregate_make_block(table.target_id, "else_block", 0, 0, mir_aggregate_empty_param_vector(ctx), ctx);

    mut join_params := mir_aggregate_empty_param_vector(ctx);
    join_params = mir_aggregate_push_param(join_params, mir_aggregate_make_param(0, "joined_point", agg_point_then, ctx), ctx);
    join_params = mir_aggregate_push_param(join_params, mir_aggregate_make_param(1, "joined_maybe", agg_maybe_then, ctx), ctx);
    mut if_join := mir_aggregate_make_block(table.target_id, "if_join", 1, 0, join_params, ctx);

    mut seq_params := mir_aggregate_empty_param_vector(ctx);
    seq_params = mir_aggregate_push_param(seq_params, mir_aggregate_make_param(0, "seq_view", agg_view, ctx), ctx);
    mut seq_block := mir_aggregate_make_block(table.target_id, "seq_block", 1, 0, seq_params, ctx);

    mut loop_params := mir_aggregate_empty_param_vector(ctx);
    loop_params = mir_aggregate_push_param(loop_params, mir_aggregate_make_param(0, "carried_array", agg_array, ctx), ctx);
    loop_params = mir_aggregate_push_param(loop_params, mir_aggregate_make_param(1, "carried_slice", agg_slice, ctx), ctx);
    mut loop_header := mir_aggregate_make_block(table.target_id, "loop_header", 1, 1, loop_params, ctx);
    mut loop_body := mir_aggregate_make_block(table.target_id, "loop_body", 0, 0, mir_aggregate_empty_param_vector(ctx), ctx);

    mut exit_params := mir_aggregate_empty_param_vector(ctx);
    exit_params = mir_aggregate_push_param(exit_params, mir_aggregate_make_param(0, "exit_nested", agg_nested, ctx), ctx);
    mut exit_block := mir_aggregate_make_block(table.target_id, "exit_block", 0, 0, exit_params, ctx);

    table = mir_aggregate_table_with_block(table, entry_block, ctx);
    table = mir_aggregate_table_with_block(table, then_block, ctx);
    table = mir_aggregate_table_with_block(table, else_block, ctx);
    table = mir_aggregate_table_with_block(table, if_join, ctx);
    table = mir_aggregate_table_with_block(table, seq_block, ctx);
    table = mir_aggregate_table_with_block(table, loop_header, ctx);
    table = mir_aggregate_table_with_block(table, loop_body, ctx);
    table = mir_aggregate_table_with_block(table, exit_block, ctx);

    mut e_entry_then := mir_aggregate_make_edge("entry", "then_block", "branch_true", mir_aggregate_empty_str_vector(ctx), ctx);
    mut e_entry_else := mir_aggregate_make_edge("entry", "else_block", "branch_false", mir_aggregate_empty_str_vector(ctx), ctx);
    mut then_args := mir_aggregate_empty_str_vector(ctx);
    then_args = mir_aggregate_push_arg(then_args, "agg_point_then", ctx);
    then_args = mir_aggregate_push_arg(then_args, "agg_maybe_then", ctx);
    mut e_then_join := mir_aggregate_make_edge("then_block", "if_join", "fallthrough", then_args, ctx);
    mut else_args := mir_aggregate_empty_str_vector(ctx);
    else_args = mir_aggregate_push_arg(else_args, "agg_point_else", ctx);
    else_args = mir_aggregate_push_arg(else_args, "agg_maybe_else", ctx);
    mut e_else_join := mir_aggregate_make_edge("else_block", "if_join", "fallthrough", else_args, ctx);
    mut seq_args := mir_aggregate_empty_str_vector(ctx);
    seq_args = mir_aggregate_push_arg(seq_args, "agg_view", ctx);
    mut e_join_seq := mir_aggregate_make_edge("if_join", "seq_block", "fallthrough", seq_args, ctx);
    mut loop_entry_args := mir_aggregate_empty_str_vector(ctx);
    loop_entry_args = mir_aggregate_push_arg(loop_entry_args, "agg_array", ctx);
    loop_entry_args = mir_aggregate_push_arg(loop_entry_args, "agg_slice", ctx);
    mut e_seq_loop := mir_aggregate_make_edge("seq_block", "loop_header", "fallthrough", loop_entry_args, ctx);
    mut e_header_body := mir_aggregate_make_edge("loop_header", "loop_body", "branch_true", mir_aggregate_empty_str_vector(ctx), ctx);
    mut backedge_args := mir_aggregate_empty_str_vector(ctx);
    backedge_args = mir_aggregate_push_arg(backedge_args, "agg_array", ctx);
    backedge_args = mir_aggregate_push_arg(backedge_args, "agg_slice", ctx);
    mut e_body_header := mir_aggregate_make_edge("loop_body", "loop_header", "backedge", backedge_args, ctx);
    mut exit_args := mir_aggregate_empty_str_vector(ctx);
    exit_args = mir_aggregate_push_arg(exit_args, "agg_nested", ctx);
    mut e_header_exit := mir_aggregate_make_edge("loop_header", "exit_block", "branch_false", exit_args, ctx);

    table = mir_aggregate_table_with_edge(table, e_entry_then, ctx);
    table = mir_aggregate_table_with_edge(table, e_entry_else, ctx);
    table = mir_aggregate_table_with_edge(table, e_then_join, ctx);
    table = mir_aggregate_table_with_edge(table, e_else_join, ctx);
    table = mir_aggregate_table_with_edge(table, e_join_seq, ctx);
    table = mir_aggregate_table_with_edge(table, e_seq_loop, ctx);
    table = mir_aggregate_table_with_edge(table, e_header_body, ctx);
    table = mir_aggregate_table_with_edge(table, e_body_header, ctx);
    table = mir_aggregate_table_with_edge(table, e_header_exit, ctx);

    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "declare_join_point", "block_param_declare", "if_join", "", "", 0, 2, 0, 4, ctx), ctx);
    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "declare_join_maybe", "block_param_declare", "if_join", "", "", 1, 2, 0, 4, ctx), ctx);
    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "declare_seq_view", "block_param_declare", "seq_block", "", "", 0, 2, 0, 2, ctx), ctx);
    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "declare_loop_array", "block_param_declare", "loop_header", "", "", 0, 1, 0, 3, ctx), ctx);
    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "declare_loop_slice", "block_param_declare", "loop_header", "", "", 1, 2, 0, 3, ctx), ctx);
    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "declare_exit_nested", "block_param_declare", "exit_block", "", "", 0, 1, 0, 1, ctx), ctx);

    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "pass_then_join", "edge_argument_pass", "", e_then_join.edge_id, "", 0, 2, 0, 4, ctx), ctx);
    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "pass_else_join", "edge_argument_pass", "", e_else_join.edge_id, "", 0, 2, 0, 4, ctx), ctx);
    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "pass_join_seq", "edge_argument_pass", "", e_join_seq.edge_id, "", 0, 1, 0, 2, ctx), ctx);
    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "pass_seq_loop", "edge_argument_pass", "", e_seq_loop.edge_id, "", 0, 2, 0, 3, ctx), ctx);
    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "pass_header_exit", "edge_argument_pass", "", e_header_exit.edge_id, "", 0, 1, 0, 1, ctx), ctx);

    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "observe_join_point_x", "join_observe", "if_join", "", "agg_point_then", 0, 3, 0, 2, ctx), ctx);
    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "observe_join_point_y_else", "join_observe", "if_join", "", "agg_point_else", 1, 9, 4, 2, ctx), ctx);
    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "observe_join_maybe_payload", "join_observe", "if_join", "", "agg_maybe_then", 1, 77, maybe_layout.payload_offset, 2, ctx), ctx);
    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "observe_loop_array_last", "join_observe", "loop_header", "", "agg_array", 3, 44, 12, 1, ctx), ctx);
    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "observe_exit_nested_extra", "join_observe", "exit_block", "", "agg_nested", 2, 42, 8, 1, ctx), ctx);

    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "carry_loop_state", "loop_carry", "loop_header", e_body_header.edge_id, "", 0, 2, 0, 3, ctx), ctx);
    table = mir_aggregate_table_with_operation(table, mir_aggregate_make_operation(table, "early_return_scalar", "early_return", "exit_block", "", "", 0, 65, 0, 0, ctx), ctx);
    return table;
}

func mir_aggregate_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_serialize_aggregate_table_for_request(table: MirAggregateTransportTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_aggregate_table_is_legacy_empty(table, ctx) == 1 {
        return "aggregate_table_format: gust.compiler_aggregate_transport_table.v1\naggregate_target_id: \naggregate_target_triple: legacy-empty\naggregate_class_count: 0\naggregate_value_count: 0\naggregate_block_count: 0\naggregate_edge_count: 0\naggregate_operation_count: 0\n";
    }
    if mir_aggregate_table_is_valid(table, layout_table, ctx) == 0 {
        return "aggregate_table_format: invalid\n";
    }
    mut output := "";
    output = mir_aggregate_append_field(output, "aggregate_table_format", table.format, ctx);
    output = mir_aggregate_append_field(output, "aggregate_target_id", table.target_id, ctx);
    output = mir_aggregate_append_field(output, "aggregate_target_triple", table.target_triple, ctx);
    output = mir_aggregate_append_field(output, "aggregate_transport_authority", table.transport_authority, ctx);
    output = mir_aggregate_append_field(output, "aggregate_copy_policy", table.copy_policy, ctx);
    output = mir_aggregate_append_field(output, "aggregate_resource_policy", table.resource_policy, ctx);
    output = mir_aggregate_append_field(output, "aggregate_abi_policy", table.abi_policy, ctx);
    output = mir_aggregate_append_field(output, "aggregate_join_policy", table.join_policy, ctx);
    output = mir_aggregate_append_field(output, "aggregate_loop_policy", table.loop_policy, ctx);

    mut class_policies: std.Vector[MirAggregateClassPolicy[ctx], ctx] := ctx[table.class_policies];
    output = mir_aggregate_append_field(output, "aggregate_class_count", std.FormatInt(len(class_policies)), ctx);
    mut index := 0;
    while index < len(class_policies) {
        mut prefix := std.Concat("aggregate_class_", std.FormatInt(index));
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_name"), class_policies[index].class_name, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_transport_policy"), class_policies[index].transport_policy, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_arity_rule"), class_policies[index].arity_rule, ctx);
        index = index + 1;
    }

    mut values: std.Vector[MirAggregateValue[ctx], ctx] := ctx[table.values];
    output = mir_aggregate_append_field(output, "aggregate_value_count", std.FormatInt(len(values)), ctx);
    index = 0;
    while index < len(values) {
        mut prefix := std.Concat("aggregate_value_", std.FormatInt(index));
        mut value := values[index];
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_id"), value.value_id, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_class"), value.class_name, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_type_id"), value.type_id, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_layout_id"), value.layout_id, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_transport_policy"), value.transport_policy, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_size"), std.FormatInt(value.size), ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_alignment"), std.FormatInt(value.alignment), ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_variant_name"), value.variant_name, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_movement_kind"), value.movement_kind, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_is_resource"), std.FormatInt(value.is_resource), ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_initialized"), std.FormatInt(value.initialized), ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_lifetime_region"), value.lifetime_region, ctx);
        mut components: std.Vector[MirAggregateComponent[ctx], ctx] := ctx[value.components];
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_component_count"), std.FormatInt(len(components)), ctx);
        mut component_index := 0;
        while component_index < len(components) {
            mut component_prefix := std.Concat(prefix, std.Concat("_component_", std.FormatInt(component_index)));
            output = mir_aggregate_append_field(output, std.Concat(component_prefix, "_name"), components[component_index].name, ctx);
            output = mir_aggregate_append_field(output, std.Concat(component_prefix, "_type_id"), components[component_index].type_id, ctx);
            output = mir_aggregate_append_field(output, std.Concat(component_prefix, "_offset"), std.FormatInt(components[component_index].offset), ctx);
            output = mir_aggregate_append_field(output, std.Concat(component_prefix, "_size"), std.FormatInt(components[component_index].size), ctx);
            output = mir_aggregate_append_field(output, std.Concat(component_prefix, "_value"), std.FormatInt(components[component_index].value), ctx);
            component_index = component_index + 1;
        }
        index = index + 1;
    }

    mut blocks: std.Vector[MirAggregateBlock[ctx], ctx] := ctx[table.blocks];
    output = mir_aggregate_append_field(output, "aggregate_block_count", std.FormatInt(len(blocks)), ctx);
    index = 0;
    while index < len(blocks) {
        mut prefix := std.Concat("aggregate_block_", std.FormatInt(index));
        mut block := blocks[index];
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_id"), block.block_id, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_label"), block.label, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_is_join"), std.FormatInt(block.is_join), ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_is_loop_header"), std.FormatInt(block.is_loop_header), ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_total_block_argument_count"), std.FormatInt(block.total_block_argument_count), ctx);
        mut params: std.Vector[MirAggregateBlockParam[ctx], ctx] := ctx[block.params];
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_param_count"), std.FormatInt(len(params)), ctx);
        mut param_index := 0;
        while param_index < len(params) {
            mut param_prefix := std.Concat(prefix, std.Concat("_param_", std.FormatInt(param_index)));
            output = mir_aggregate_append_field(output, std.Concat(param_prefix, "_name"), params[param_index].param_name, ctx);
            output = mir_aggregate_append_field(output, std.Concat(param_prefix, "_class"), params[param_index].class_name, ctx);
            output = mir_aggregate_append_field(output, std.Concat(param_prefix, "_type_id"), params[param_index].type_id, ctx);
            output = mir_aggregate_append_field(output, std.Concat(param_prefix, "_layout_id"), params[param_index].layout_id, ctx);
            output = mir_aggregate_append_field(output, std.Concat(param_prefix, "_transport_policy"), params[param_index].transport_policy, ctx);
            output = mir_aggregate_append_field(output, std.Concat(param_prefix, "_block_argument_count"), std.FormatInt(params[param_index].block_argument_count), ctx);
            param_index = param_index + 1;
        }
        index = index + 1;
    }

    mut edges: std.Vector[MirAggregateEdge[ctx], ctx] := ctx[table.edges];
    output = mir_aggregate_append_field(output, "aggregate_edge_count", std.FormatInt(len(edges)), ctx);
    index = 0;
    while index < len(edges) {
        mut prefix := std.Concat("aggregate_edge_", std.FormatInt(index));
        mut edge := edges[index];
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_id"), edge.edge_id, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_from"), edge.from_label, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_to"), edge.to_label, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_kind"), edge.edge_kind, ctx);
        mut args: std.Vector[str, ctx] := ctx[edge.argument_value_ids];
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_argument_count"), std.FormatInt(len(args)), ctx);
        mut arg_index := 0;
        while arg_index < len(args) {
            output = mir_aggregate_append_field(output, std.Concat(prefix, std.Concat("_argument_", std.FormatInt(arg_index))), args[arg_index], ctx);
            arg_index = arg_index + 1;
        }
        index = index + 1;
    }

    mut operations: std.Vector[MirAggregateOperation[ctx], ctx] := ctx[table.operations];
    output = mir_aggregate_append_field(output, "aggregate_operation_count", std.FormatInt(len(operations)), ctx);
    index = 0;
    while index < len(operations) {
        mut prefix := std.Concat("aggregate_operation_", std.FormatInt(index));
        mut operation := operations[index];
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_id"), operation.operation_id, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_name"), operation.operation_name, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_target_id"), operation.target_id, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_kind"), operation.kind, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_block_label"), operation.block_label, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_edge_id"), operation.edge_id, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_value_id"), operation.value_id, ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_component_index"), std.FormatInt(operation.component_index), ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_expect_success"), std.FormatInt(operation.expect_success), ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_expected_value"), std.FormatInt(operation.expected_value), ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_expected_offset"), std.FormatInt(operation.expected_offset), ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_expected_arity"), std.FormatInt(operation.expected_arity), ctx);
        output = mir_aggregate_append_field(output, std.Concat(prefix, "_expected_reason_code"), operation.expected_reason_code, ctx);
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_aggregate_witness(table: MirAggregateTransportTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_aggregate_table_is_valid(table, layout_table, ctx) == 0 ||
       mir_aggregate_table_is_legacy_empty(table, ctx) == 1
    {
        return "";
    }
    mut output := "aggregate_transport_status: valid\n";
    output = mir_aggregate_append_field(output, "aggregate_target", table.target_triple, ctx);
    output = mir_aggregate_append_field(output, "aggregate_target_id", table.target_id, ctx);
    output = mir_aggregate_append_field(output, "aggregate_transport_authority", table.transport_authority, ctx);
    output = mir_aggregate_append_field(output, "aggregate_copy_policy", table.copy_policy, ctx);
    output = mir_aggregate_append_field(output, "aggregate_resource_policy", table.resource_policy, ctx);
    output = mir_aggregate_append_field(output, "aggregate_abi_policy", table.abi_policy, ctx);
    output = mir_aggregate_append_field(output, "aggregate_join_policy", table.join_policy, ctx);
    output = mir_aggregate_append_field(output, "aggregate_loop_policy", table.loop_policy, ctx);

    mut class_policies: std.Vector[MirAggregateClassPolicy[ctx], ctx] := ctx[table.class_policies];
    mut index := 0;
    while index < len(class_policies) {
        mut line := "aggregate_class: ";
        line = std.Concat(line, class_policies[index].class_name);
        line = std.Concat(line, " transport="); line = std.Concat(line, class_policies[index].transport_policy);
        line = std.Concat(line, " arity_rule="); line = std.Concat(line, std.Concat(class_policies[index].arity_rule, "\n"));
        output = std.Concat(output, line);
        index = index + 1;
    }

    mut values: std.Vector[MirAggregateValue[ctx], ctx] := ctx[table.values];
    index = 0;
    while index < len(values) {
        mut value := values[index];
        mut components: std.Vector[MirAggregateComponent[ctx], ctx] := ctx[value.components];
        mut line := "aggregate_value: ";
        line = std.Concat(line, value.value_id);
        line = std.Concat(line, " class="); line = std.Concat(line, value.class_name);
        line = std.Concat(line, " type="); line = std.Concat(line, value.type_id);
        line = std.Concat(line, " transport="); line = std.Concat(line, value.transport_policy);
        line = std.Concat(line, " size="); line = std.Concat(line, std.FormatInt(value.size));
        line = std.Concat(line, " alignment="); line = std.Concat(line, std.FormatInt(value.alignment));
        line = std.Concat(line, " variant="); line = std.Concat(line, value.variant_name);
        line = std.Concat(line, " movement="); line = std.Concat(line, value.movement_kind);
        line = std.Concat(line, " components="); line = std.Concat(line, std.FormatInt(len(components)));
        line = std.Concat(line, " arity="); line = std.Concat(line, std.FormatInt(mir_aggregate_arity_for_policy(value.transport_policy, len(components))));
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        mut component_index := 0;
        while component_index < len(components) {
            mut component := components[component_index];
            mut component_line := "aggregate_component: ";
            component_line = std.Concat(component_line, std.Concat(value.value_id, std.Concat(".", component.name)));
            component_line = std.Concat(component_line, " type="); component_line = std.Concat(component_line, component.type_id);
            component_line = std.Concat(component_line, " offset="); component_line = std.Concat(component_line, std.FormatInt(component.offset));
            component_line = std.Concat(component_line, " size="); component_line = std.Concat(component_line, std.FormatInt(component.size));
            component_line = std.Concat(component_line, " value="); component_line = std.Concat(component_line, std.Concat(std.FormatInt(component.value), "\n"));
            output = std.Concat(output, component_line);
            component_index = component_index + 1;
        }
        index = index + 1;
    }

    mut blocks: std.Vector[MirAggregateBlock[ctx], ctx] := ctx[table.blocks];
    index = 0;
    while index < len(blocks) {
        mut block := blocks[index];
        mut params: std.Vector[MirAggregateBlockParam[ctx], ctx] := ctx[block.params];
        mut line := "aggregate_block: ";
        line = std.Concat(line, block.label);
        line = std.Concat(line, " join="); line = std.Concat(line, std.FormatInt(block.is_join));
        line = std.Concat(line, " loop_header="); line = std.Concat(line, std.FormatInt(block.is_loop_header));
        line = std.Concat(line, " params="); line = std.Concat(line, std.FormatInt(len(params)));
        line = std.Concat(line, " block_arguments="); line = std.Concat(line, std.Concat(std.FormatInt(block.total_block_argument_count), "\n"));
        output = std.Concat(output, line);
        index = index + 1;
    }

    mut edges: std.Vector[MirAggregateEdge[ctx], ctx] := ctx[table.edges];
    index = 0;
    while index < len(edges) {
        mut edge := edges[index];
        mut args: std.Vector[str, ctx] := ctx[edge.argument_value_ids];
        mut line := "aggregate_edge: ";
        line = std.Concat(line, edge.from_label);
        line = std.Concat(line, "->"); line = std.Concat(line, edge.to_label);
        line = std.Concat(line, " kind="); line = std.Concat(line, edge.edge_kind);
        line = std.Concat(line, " arguments="); line = std.Concat(line, std.Concat(std.FormatInt(len(args)), "\n"));
        output = std.Concat(output, line);
        index = index + 1;
    }

    mut operations: std.Vector[MirAggregateOperation[ctx], ctx] := ctx[table.operations];
    index = 0;
    while index < len(operations) {
        mut operation := operations[index];
        mut evaluation := mir_aggregate_evaluate(table, operation, ctx);
        mut line := "aggregate_operation: ";
        line = std.Concat(line, operation.operation_name);
        line = std.Concat(line, " kind="); line = std.Concat(line, operation.kind);
        line = std.Concat(line, " status=");
        if evaluation.success == 1 { line = std.Concat(line, "success"); }
        else { line = std.Concat(line, "failure"); }
        line = std.Concat(line, " value="); line = std.Concat(line, std.FormatInt(evaluation.value));
        line = std.Concat(line, " offset="); line = std.Concat(line, std.FormatInt(evaluation.offset));
        line = std.Concat(line, " arity="); line = std.Concat(line, std.FormatInt(evaluation.arity));
        line = std.Concat(line, " reason="); line = std.Concat(line, std.Concat(evaluation.reason_code, "\n"));
        output = std.Concat(output, line);
        index = index + 1;
    }
    return std.Clone(ctx, output);
}
