// Phase 16.1 compiler-owned function ABI authority.
//
// This module is the sole semantic owner for function ABI identity, value
// classification, parameter/result placement, call-site plans, bounded frame
// plans, and compatibility decisions. Canonical MIR metadata, MIR-to-C,
// Cranelift, runtime-facing calls, and diagnostics consume these records.
// Backend signatures, generated C declarations, worker control flow, source
// spelling, and emitted object structure are not semantic ABI authority.

import "mir_layout.gst" as layout;
import "mir_resource_authority.gst" as resource;

type MirFunctionAbiIdentity[ctx] struct {
    abi_id: str,
    function_id: str,
    signature_id: str,
    calling_convention: str,
    target_id: str,
    target_triple: str,
    parameter_placement_ids: Index[std.Vector[str, ctx], ctx],
    result_placement_ids: Index[std.Vector[str, ctx], ctx]
}

type MirAbiValueClassification[ctx] struct {
    classification_id: str,
    type_id: str,
    layout_id: str,
    position: str,
    value_class: str,
    register_class: str,
    size_bytes: int,
    align_bytes: int,
    target_id: str,
    target_triple: str
}

type MirAbiParameterPlacement[ctx] struct {
    placement_id: str,
    abi_id: str,
    parameter_id: str,
    ordinal: int,
    classification_id: str,
    passing_mode: str,
    location: str,
    layout_id: str,
    resource_id: str,
    hidden: int
}

type MirAbiResultPlacement[ctx] struct {
    placement_id: str,
    abi_id: str,
    result_id: str,
    ordinal: int,
    classification_id: str,
    passing_mode: str,
    location: str,
    layout_id: str,
    resource_id: str,
    hidden: int
}

type MirAbiCallSitePlan[ctx] struct {
    call_plan_id: str,
    call_site_id: str,
    caller_function_id: str,
    callee_function_id: str,
    expected_abi_id: str,
    actual_abi_id: str,
    argument_placement_ids: Index[std.Vector[str, ctx], ctx],
    result_placement_ids: Index[std.Vector[str, ctx], ctx],
    signature_compatible: int,
    target_id: str,
    target_triple: str
}

type MirDynamicFramePlan[ctx] struct {
    frame_plan_id: str,
    function_id: str,
    fixed_size_bytes: int,
    dynamic_size_value_id: str,
    alignment_bytes: int,
    cleanup_scope_id: str,
    bounded: int,
    target_id: str,
    target_triple: str
}

type MirAbiCompatibilityDecision[ctx] struct {
    decision_id: str,
    expected_abi_id: str,
    actual_abi_id: str,
    compatible: int,
    reason_code: str
}

// Associated canonical-MIR metadata. The producer records the canonical MIR
// function, call, and result operations that consume each ABI identity.
type MirAbiMirReference[ctx] struct {
    reference_id: str,
    mir_function_id: str,
    mir_call_id: str,
    mir_result_id: str,
    abi_id: str,
    call_plan_id: str,
    frame_plan_id: str
}

type MirFunctionAbiAuthorityTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    semantic_authority: str,
    identity_policy: str,
    classification_policy: str,
    placement_policy: str,
    functions: Index[std.Vector[MirFunctionAbiIdentity[ctx], ctx], ctx],
    classifications: Index[std.Vector[MirAbiValueClassification[ctx], ctx], ctx],
    parameter_placements: Index[std.Vector[MirAbiParameterPlacement[ctx], ctx], ctx],
    result_placements: Index[std.Vector[MirAbiResultPlacement[ctx], ctx], ctx],
    call_plans: Index[std.Vector[MirAbiCallSitePlan[ctx], ctx], ctx],
    frame_plans: Index[std.Vector[MirDynamicFramePlan[ctx], ctx], ctx],
    compatibility_decisions: Index[std.Vector[MirAbiCompatibilityDecision[ctx], ctx], ctx],
    mir_references: Index[std.Vector[MirAbiMirReference[ctx], ctx], ctx]
}

type MirFunctionAbiQuery[ctx] struct { found: int, value: MirFunctionAbiIdentity[ctx] }
type MirAbiClassificationQuery[ctx] struct { found: int, value: MirAbiValueClassification[ctx] }
type MirAbiCallPlanQuery[ctx] struct { found: int, value: MirAbiCallSitePlan[ctx] }
type MirDynamicFramePlanQuery[ctx] struct { found: int, value: MirDynamicFramePlan[ctx] }
type MirAbiCompatibilityQuery[ctx] struct { compatible: int, reason_code: str }
type MirFunctionAbiTableValidation[ctx] struct { valid: int, reason_code: str }

func mir_abi_empty_str_vector(ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut values: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_abi_empty_function_vector(ctx: &Arena) Index[std.Vector[MirFunctionAbiIdentity[ctx], ctx], ctx] {
    mut values: std.Vector[MirFunctionAbiIdentity[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirFunctionAbiIdentity[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_abi_empty_classification_vector(ctx: &Arena) Index[std.Vector[MirAbiValueClassification[ctx], ctx], ctx] {
    mut values: std.Vector[MirAbiValueClassification[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAbiValueClassification[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_abi_empty_parameter_vector(ctx: &Arena) Index[std.Vector[MirAbiParameterPlacement[ctx], ctx], ctx] {
    mut values: std.Vector[MirAbiParameterPlacement[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAbiParameterPlacement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_abi_empty_result_vector(ctx: &Arena) Index[std.Vector[MirAbiResultPlacement[ctx], ctx], ctx] {
    mut values: std.Vector[MirAbiResultPlacement[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAbiResultPlacement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_abi_empty_call_plan_vector(ctx: &Arena) Index[std.Vector[MirAbiCallSitePlan[ctx], ctx], ctx] {
    mut values: std.Vector[MirAbiCallSitePlan[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAbiCallSitePlan[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_abi_empty_frame_plan_vector(ctx: &Arena) Index[std.Vector[MirDynamicFramePlan[ctx], ctx], ctx] {
    mut values: std.Vector[MirDynamicFramePlan[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirDynamicFramePlan[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_abi_empty_compatibility_vector(ctx: &Arena) Index[std.Vector[MirAbiCompatibilityDecision[ctx], ctx], ctx] {
    mut values: std.Vector[MirAbiCompatibilityDecision[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAbiCompatibilityDecision[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_abi_empty_reference_vector(ctx: &Arena) Index[std.Vector[MirAbiMirReference[ctx], ctx], ctx] {
    mut values: std.Vector[MirAbiMirReference[ctx], ctx] := std.VectorNew(ctx);
    mut index: Index[std.Vector[MirAbiMirReference[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func mir_abi_push_string(values_index: Index[std.Vector[str, ctx], ctx], value: str, ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut values: std.Vector[str, ctx] := ctx[values_index];
    values.Push(std.Clone(ctx, value));
    ctx.Set(values_index, values);
    return values_index;
}

func mir_abi_field_is_safe(value: str, allow_empty: int) int {
    if allow_empty == 0 && len(value) == 0 { return 0; }
    if std.str_find(value, "\n") != 0 - 1 { return 0; }
    if std.str_find(value, "\r") != 0 - 1 { return 0; }
    return 1;
}

func mir_abi_position_is_valid(position: str) int {
    if std.str_eq(position, "parameter") == 1 { return 1; }
    if std.str_eq(position, "result") == 1 { return 1; }
    if std.str_eq(position, "hidden_result") == 1 { return 1; }
    if std.str_eq(position, "frame") == 1 { return 1; }
    return 0;
}

func mir_abi_passing_mode_is_valid(mode: str) int {
    if std.str_eq(mode, "direct") == 1 { return 1; }
    if std.str_eq(mode, "split") == 1 { return 1; }
    if std.str_eq(mode, "indirect_by_value") == 1 { return 1; }
    if std.str_eq(mode, "indirect_by_reference") == 1 { return 1; }
    if std.str_eq(mode, "hidden_pointer") == 1 { return 1; }
    return 0;
}

// Deterministic request-local semantic identities. They derive from compiler
// function/type/call state plus request ordinals. Raw file, registry, MIR,
// generated-C, object, or Markdown bytes never participate.
func mir_function_abi_identity_id(module_id: str, function_id: str, signature_id: str, target_id: str, request_ordinal: int, ctx: &Arena) str {
    mut identity := "function_abi:v1:module=";
    identity = std.Concat(identity, module_id);
    identity = std.Concat(identity, ":function=");
    identity = std.Concat(identity, function_id);
    identity = std.Concat(identity, ":signature=");
    identity = std.Concat(identity, signature_id);
    identity = std.Concat(identity, ":target=");
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":ordinal=");
    identity = std.Concat(identity, std.FormatInt(request_ordinal));
    return std.Clone(ctx, identity);
}

func mir_abi_value_classification_id(type_id: str, position: str, target_id: str, request_ordinal: int, ctx: &Arena) str {
    mut identity := "abi_classification:v1:type=";
    identity = std.Concat(identity, type_id);
    identity = std.Concat(identity, ":position=");
    identity = std.Concat(identity, position);
    identity = std.Concat(identity, ":target=");
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":ordinal=");
    identity = std.Concat(identity, std.FormatInt(request_ordinal));
    return std.Clone(ctx, identity);
}

func mir_abi_placement_id(abi_id: str, position: str, request_ordinal: int, ctx: &Arena) str {
    mut identity := "abi_placement:v1:abi=";
    identity = std.Concat(identity, abi_id);
    identity = std.Concat(identity, ":position=");
    identity = std.Concat(identity, position);
    identity = std.Concat(identity, ":ordinal=");
    identity = std.Concat(identity, std.FormatInt(request_ordinal));
    return std.Clone(ctx, identity);
}

func mir_abi_call_site_plan_id(caller_function_id: str, call_site_id: str, expected_abi_id: str, request_ordinal: int, ctx: &Arena) str {
    mut identity := "abi_call_plan:v1:caller=";
    identity = std.Concat(identity, caller_function_id);
    identity = std.Concat(identity, ":call_site=");
    identity = std.Concat(identity, call_site_id);
    identity = std.Concat(identity, ":expected=");
    identity = std.Concat(identity, expected_abi_id);
    identity = std.Concat(identity, ":ordinal=");
    identity = std.Concat(identity, std.FormatInt(request_ordinal));
    return std.Clone(ctx, identity);
}

func mir_dynamic_frame_plan_id(function_id: str, target_id: str, request_ordinal: int, ctx: &Arena) str {
    mut identity := "abi_frame_plan:v1:function=";
    identity = std.Concat(identity, function_id);
    identity = std.Concat(identity, ":target=");
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":ordinal=");
    identity = std.Concat(identity, std.FormatInt(request_ordinal));
    return std.Clone(ctx, identity);
}

func mir_function_abi_make_empty_table(target_id: str, target_triple: str, ctx: &Arena) MirFunctionAbiAuthorityTable[ctx] {
    mut table: MirFunctionAbiAuthorityTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_function_abi_authority_table.v1");
    table.target_id = std.Clone(ctx, target_id);
    table.target_triple = std.Clone(ctx, target_triple);
    table.semantic_authority = std.Clone(ctx, "compiler_owned_function_abi_authority");
    table.identity_policy = std.Clone(ctx, "compiler_semantic_state_plus_request_ordinal_no_raw_hash");
    table.classification_policy = std.Clone(ctx, "compiler_owned_target_aware_value_classification");
    table.placement_policy = std.Clone(ctx, "compiler_owned_caller_callee_placement_agreement");
    table.functions = mir_abi_empty_function_vector(ctx);
    table.classifications = mir_abi_empty_classification_vector(ctx);
    table.parameter_placements = mir_abi_empty_parameter_vector(ctx);
    table.result_placements = mir_abi_empty_result_vector(ctx);
    table.call_plans = mir_abi_empty_call_plan_vector(ctx);
    table.frame_plans = mir_abi_empty_frame_plan_vector(ctx);
    table.compatibility_decisions = mir_abi_empty_compatibility_vector(ctx);
    table.mir_references = mir_abi_empty_reference_vector(ctx);
    return table;
}

func mir_function_abi_table_with_function(table: MirFunctionAbiAuthorityTable[ctx], value: MirFunctionAbiIdentity[ctx], ctx: &Arena) MirFunctionAbiAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirFunctionAbiIdentity[ctx], ctx] := ctx[updated.functions];
    values.Push(value);
    ctx.Set(updated.functions, values);
    return updated;
}

func mir_function_abi_table_with_classification(table: MirFunctionAbiAuthorityTable[ctx], value: MirAbiValueClassification[ctx], ctx: &Arena) MirFunctionAbiAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAbiValueClassification[ctx], ctx] := ctx[updated.classifications];
    values.Push(value);
    ctx.Set(updated.classifications, values);
    return updated;
}

func mir_function_abi_table_with_parameter(table: MirFunctionAbiAuthorityTable[ctx], value: MirAbiParameterPlacement[ctx], ctx: &Arena) MirFunctionAbiAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAbiParameterPlacement[ctx], ctx] := ctx[updated.parameter_placements];
    values.Push(value);
    ctx.Set(updated.parameter_placements, values);
    return updated;
}

func mir_function_abi_table_with_result(table: MirFunctionAbiAuthorityTable[ctx], value: MirAbiResultPlacement[ctx], ctx: &Arena) MirFunctionAbiAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAbiResultPlacement[ctx], ctx] := ctx[updated.result_placements];
    values.Push(value);
    ctx.Set(updated.result_placements, values);
    return updated;
}

func mir_function_abi_table_with_call_plan(table: MirFunctionAbiAuthorityTable[ctx], value: MirAbiCallSitePlan[ctx], ctx: &Arena) MirFunctionAbiAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAbiCallSitePlan[ctx], ctx] := ctx[updated.call_plans];
    values.Push(value);
    ctx.Set(updated.call_plans, values);
    return updated;
}

func mir_function_abi_table_with_frame_plan(table: MirFunctionAbiAuthorityTable[ctx], value: MirDynamicFramePlan[ctx], ctx: &Arena) MirFunctionAbiAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirDynamicFramePlan[ctx], ctx] := ctx[updated.frame_plans];
    values.Push(value);
    ctx.Set(updated.frame_plans, values);
    return updated;
}

func mir_function_abi_table_with_compatibility(table: MirFunctionAbiAuthorityTable[ctx], value: MirAbiCompatibilityDecision[ctx], ctx: &Arena) MirFunctionAbiAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAbiCompatibilityDecision[ctx], ctx] := ctx[updated.compatibility_decisions];
    values.Push(value);
    ctx.Set(updated.compatibility_decisions, values);
    return updated;
}

func mir_function_abi_table_with_mir_reference(table: MirFunctionAbiAuthorityTable[ctx], value: MirAbiMirReference[ctx], ctx: &Arena) MirFunctionAbiAuthorityTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirAbiMirReference[ctx], ctx] := ctx[updated.mir_references];
    values.Push(value);
    ctx.Set(updated.mir_references, values);
    return updated;
}

func mir_function_abi_by_id(table: MirFunctionAbiAuthorityTable[ctx], abi_id: str, ctx: &Arena) MirFunctionAbiQuery[ctx] {
    mut result: MirFunctionAbiQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirFunctionAbiIdentity[ctx], ctx] := ctx[table.functions];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].abi_id, abi_id) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

// function_abi(function, target)
func mir_function_abi(table: MirFunctionAbiAuthorityTable[ctx], function_id: str, target_id: str, ctx: &Arena) MirFunctionAbiQuery[ctx] {
    mut result: MirFunctionAbiQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirFunctionAbiIdentity[ctx], ctx] := ctx[table.functions];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].function_id, function_id) == 1 &&
           std.str_eq(values[index].target_id, target_id) == 1
        {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_abi_classification_by_id(table: MirFunctionAbiAuthorityTable[ctx], classification_id: str, ctx: &Arena) MirAbiClassificationQuery[ctx] {
    mut result: MirAbiClassificationQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirAbiValueClassification[ctx], ctx] := ctx[table.classifications];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].classification_id, classification_id) == 1 {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

// classify_abi_value(type, position, target)
func mir_classify_abi_value(table: MirFunctionAbiAuthorityTable[ctx], type_id: str, position: str, target_id: str, ctx: &Arena) MirAbiClassificationQuery[ctx] {
    mut result: MirAbiClassificationQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirAbiValueClassification[ctx], ctx] := ctx[table.classifications];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].type_id, type_id) == 1 &&
           std.str_eq(values[index].position, position) == 1 &&
           std.str_eq(values[index].target_id, target_id) == 1
        {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

// parameter_placements(function_abi)
func mir_parameter_placements(table: MirFunctionAbiAuthorityTable[ctx], abi_id: str, ctx: &Arena) Index[std.Vector[MirAbiParameterPlacement[ctx], ctx], ctx] {
    mut result := mir_abi_empty_parameter_vector(ctx);
    mut output: std.Vector[MirAbiParameterPlacement[ctx], ctx] := ctx[result];
    mut values: std.Vector[MirAbiParameterPlacement[ctx], ctx] := ctx[table.parameter_placements];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].abi_id, abi_id) == 1 { output.Push(values[index]); }
        index = index + 1;
    }
    ctx.Set(result, output);
    return result;
}

// result_placements(function_abi)
func mir_result_placements(table: MirFunctionAbiAuthorityTable[ctx], abi_id: str, ctx: &Arena) Index[std.Vector[MirAbiResultPlacement[ctx], ctx], ctx] {
    mut result := mir_abi_empty_result_vector(ctx);
    mut output: std.Vector[MirAbiResultPlacement[ctx], ctx] := ctx[result];
    mut values: std.Vector[MirAbiResultPlacement[ctx], ctx] := ctx[table.result_placements];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].abi_id, abi_id) == 1 { output.Push(values[index]); }
        index = index + 1;
    }
    ctx.Set(result, output);
    return result;
}

// call_plan(call_site, expected_abi)
func mir_abi_call_plan(table: MirFunctionAbiAuthorityTable[ctx], call_site_id: str, expected_abi_id: str, ctx: &Arena) MirAbiCallPlanQuery[ctx] {
    mut result: MirAbiCallPlanQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirAbiCallSitePlan[ctx], ctx] := ctx[table.call_plans];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].call_site_id, call_site_id) == 1 &&
           std.str_eq(values[index].expected_abi_id, expected_abi_id) == 1
        {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

// frame_plan(function, target)
func mir_abi_frame_plan(table: MirFunctionAbiAuthorityTable[ctx], function_id: str, target_id: str, ctx: &Arena) MirDynamicFramePlanQuery[ctx] {
    mut result: MirDynamicFramePlanQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirDynamicFramePlan[ctx], ctx] := ctx[table.frame_plans];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].function_id, function_id) == 1 &&
           std.str_eq(values[index].target_id, target_id) == 1
        {
            result.found = 1;
            result.value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_abi_compatibility_result(compatible: int, reason_code: str, ctx: &Arena) MirAbiCompatibilityQuery[ctx] {
    mut result: MirAbiCompatibilityQuery[ctx];
    result.compatible = compatible;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

// validate_abi_compatibility(expected, actual)
func mir_validate_abi_compatibility(table: MirFunctionAbiAuthorityTable[ctx], expected_abi_id: str, actual_abi_id: str, ctx: &Arena) MirAbiCompatibilityQuery[ctx] {
    mut expected := mir_function_abi_by_id(table, expected_abi_id, ctx);
    mut actual := mir_function_abi_by_id(table, actual_abi_id, ctx);
    if expected.found == 0 || actual.found == 0 {
        return mir_abi_compatibility_result(0, "abi_unknown_id", ctx);
    }
    if std.str_eq(expected.value.target_id, actual.value.target_id) == 0 ||
       std.str_eq(expected.value.target_triple, actual.value.target_triple) == 0
    {
        return mir_abi_compatibility_result(0, "abi_target_mismatch", ctx);
    }
    if std.str_eq(expected.value.signature_id, actual.value.signature_id) == 0 ||
       std.str_eq(expected.value.calling_convention, actual.value.calling_convention) == 0
    {
        return mir_abi_compatibility_result(0, "abi_signature_mismatch", ctx);
    }
    mut expected_parameters: std.Vector[str, ctx] := ctx[expected.value.parameter_placement_ids];
    mut actual_parameters: std.Vector[str, ctx] := ctx[actual.value.parameter_placement_ids];
    mut expected_results: std.Vector[str, ctx] := ctx[expected.value.result_placement_ids];
    mut actual_results: std.Vector[str, ctx] := ctx[actual.value.result_placement_ids];
    if len(expected_parameters) != len(actual_parameters) || len(expected_results) != len(actual_results) {
        return mir_abi_compatibility_result(0, "abi_signature_mismatch", ctx);
    }
    return mir_abi_compatibility_result(1, "abi_compatible", ctx);
}

func mir_function_abi_table_validation(valid: int, reason_code: str, ctx: &Arena) MirFunctionAbiTableValidation[ctx] {
    mut result: MirFunctionAbiTableValidation[ctx];
    result.valid = valid;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_abi_has_parameter_id(table: MirFunctionAbiAuthorityTable[ctx], placement_id: str, ctx: &Arena) int {
    mut values: std.Vector[MirAbiParameterPlacement[ctx], ctx] := ctx[table.parameter_placements];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].placement_id, placement_id) == 1 { return 1; }
        index = index + 1;
    }
    return 0;
}

func mir_abi_has_result_id(table: MirFunctionAbiAuthorityTable[ctx], placement_id: str, ctx: &Arena) int {
    mut values: std.Vector[MirAbiResultPlacement[ctx], ctx] := ctx[table.result_placements];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].placement_id, placement_id) == 1 { return 1; }
        index = index + 1;
    }
    return 0;
}

func mir_abi_has_call_plan_id(table: MirFunctionAbiAuthorityTable[ctx], call_plan_id: str, ctx: &Arena) int {
    mut values: std.Vector[MirAbiCallSitePlan[ctx], ctx] := ctx[table.call_plans];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].call_plan_id, call_plan_id) == 1 { return 1; }
        index = index + 1;
    }
    return 0;
}

func mir_abi_has_frame_plan_id(table: MirFunctionAbiAuthorityTable[ctx], frame_plan_id: str, ctx: &Arena) int {
    mut values: std.Vector[MirDynamicFramePlan[ctx], ctx] := ctx[table.frame_plans];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].frame_plan_id, frame_plan_id) == 1 { return 1; }
        index = index + 1;
    }
    return 0;
}

func mir_abi_has_function_reference(table: MirFunctionAbiAuthorityTable[ctx], abi_id: str, ctx: &Arena) int {
    mut values: std.Vector[MirAbiMirReference[ctx], ctx] := ctx[table.mir_references];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].abi_id, abi_id) == 1 && len(values[index].mir_function_id) != 0 { return 1; }
        index = index + 1;
    }
    return 0;
}

func mir_abi_has_call_reference(table: MirFunctionAbiAuthorityTable[ctx], call_plan_id: str, ctx: &Arena) int {
    mut values: std.Vector[MirAbiMirReference[ctx], ctx] := ctx[table.mir_references];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].call_plan_id, call_plan_id) == 1 && len(values[index].mir_call_id) != 0 { return 1; }
        index = index + 1;
    }
    return 0;
}

func mir_abi_has_frame_reference(table: MirFunctionAbiAuthorityTable[ctx], frame_plan_id: str, ctx: &Arena) int {
    mut values: std.Vector[MirAbiMirReference[ctx], ctx] := ctx[table.mir_references];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].frame_plan_id, frame_plan_id) == 1 && len(values[index].mir_function_id) != 0 { return 1; }
        index = index + 1;
    }
    return 0;
}

func mir_abi_power_of_two(value: int) int {
    if value <= 0 { return 0; }
    mut current := value;
    while current > 1 {
        mut half := current / 2;
        if half * 2 != current { return 0; }
        current = half;
    }
    return 1;
}

// Request deserialization/consistency validation. The worker validates this
// immutable compiler-produced table but never invents classifications,
// placements, call plans, hidden results, or frame plans.
func mir_function_abi_authority_table_validate(table: MirFunctionAbiAuthorityTable[ctx], layout_table: layout.MirLayoutTable[ctx], resource_table: resource.MirResourceAuthorityTable[ctx], ctx: &Arena) MirFunctionAbiTableValidation[ctx] {
    if std.str_eq(table.format, "gust.compiler_function_abi_authority_table.v1") == 0 {
        return mir_function_abi_table_validation(0, "abi_table_unknown_format", ctx);
    }
    if std.str_eq(table.target_id, layout_table.target.target_id) == 0 ||
       std.str_eq(table.target_triple, layout_table.target.target_triple) == 0 ||
       std.str_eq(table.target_id, resource_table.target_id) == 0 ||
       std.str_eq(table.target_triple, resource_table.target_triple) == 0
    {
        return mir_function_abi_table_validation(0, "abi_target_mismatch", ctx);
    }
    if std.str_eq(table.semantic_authority, "compiler_owned_function_abi_authority") == 0 ||
       std.str_eq(table.identity_policy, "compiler_semantic_state_plus_request_ordinal_no_raw_hash") == 0 ||
       std.str_eq(table.classification_policy, "compiler_owned_target_aware_value_classification") == 0 ||
       std.str_eq(table.placement_policy, "compiler_owned_caller_callee_placement_agreement") == 0
    {
        return mir_function_abi_table_validation(0, "abi_authority_policy_mismatch", ctx);
    }

    mut functions: std.Vector[MirFunctionAbiIdentity[ctx], ctx] := ctx[table.functions];
    mut classifications: std.Vector[MirAbiValueClassification[ctx], ctx] := ctx[table.classifications];
    mut parameters: std.Vector[MirAbiParameterPlacement[ctx], ctx] := ctx[table.parameter_placements];
    mut results: std.Vector[MirAbiResultPlacement[ctx], ctx] := ctx[table.result_placements];
    mut calls: std.Vector[MirAbiCallSitePlan[ctx], ctx] := ctx[table.call_plans];
    mut frames: std.Vector[MirDynamicFramePlan[ctx], ctx] := ctx[table.frame_plans];
    mut decisions: std.Vector[MirAbiCompatibilityDecision[ctx], ctx] := ctx[table.compatibility_decisions];
    mut references: std.Vector[MirAbiMirReference[ctx], ctx] := ctx[table.mir_references];

    mut index := 0;
    while index < len(classifications) {
        mut value := classifications[index];
        if mir_abi_field_is_safe(value.classification_id, 0) == 0 ||
           mir_abi_field_is_safe(value.type_id, 0) == 0 ||
           mir_abi_position_is_valid(value.position) == 0 ||
           mir_abi_field_is_safe(value.value_class, 0) == 0 ||
           value.size_bytes < 0 || mir_abi_power_of_two(value.align_bytes) == 0
        {
            return mir_function_abi_table_validation(0, "abi_impossible_placement", ctx);
        }
        if std.str_eq(value.target_id, table.target_id) == 0 ||
           std.str_eq(value.target_triple, table.target_triple) == 0
        {
            return mir_function_abi_table_validation(0, "abi_target_mismatch", ctx);
        }
        if len(value.layout_id) != 0 && layout.mir_layout_table_has_layout_id(layout_table, value.layout_id, ctx) == 0 {
            return mir_function_abi_table_validation(0, "abi_unknown_layout_or_resource_id", ctx);
        }
        mut duplicate := index + 1;
        while duplicate < len(classifications) {
            if std.str_eq(classifications[duplicate].classification_id, value.classification_id) == 1 {
                return mir_function_abi_table_validation(0, "abi_duplicate_conflicting_record", ctx);
            }
            duplicate = duplicate + 1;
        }
        index = index + 1;
    }

    index = 0;
    while index < len(functions) {
        mut value := functions[index];
        if mir_abi_field_is_safe(value.abi_id, 0) == 0 ||
           mir_abi_field_is_safe(value.function_id, 0) == 0 ||
           mir_abi_field_is_safe(value.signature_id, 0) == 0 ||
           mir_abi_field_is_safe(value.calling_convention, 0) == 0
        {
            return mir_function_abi_table_validation(0, "abi_record_invalid", ctx);
        }
        if std.str_eq(value.target_id, table.target_id) == 0 ||
           std.str_eq(value.target_triple, table.target_triple) == 0
        {
            return mir_function_abi_table_validation(0, "abi_target_mismatch", ctx);
        }
        if mir_abi_has_function_reference(table, value.abi_id, ctx) == 0 {
            return mir_function_abi_table_validation(0, "abi_metadata_inconsistent_with_canonical_mir", ctx);
        }
        mut parameter_ids: std.Vector[str, ctx] := ctx[value.parameter_placement_ids];
        mut ordinal := 0;
        while ordinal < len(parameter_ids) {
            if mir_abi_has_parameter_id(table, parameter_ids[ordinal], ctx) == 0 {
                return mir_function_abi_table_validation(0, "abi_unknown_id", ctx);
            }
            ordinal = ordinal + 1;
        }
        mut result_ids: std.Vector[str, ctx] := ctx[value.result_placement_ids];
        ordinal = 0;
        while ordinal < len(result_ids) {
            if mir_abi_has_result_id(table, result_ids[ordinal], ctx) == 0 {
                return mir_function_abi_table_validation(0, "abi_unknown_id", ctx);
            }
            ordinal = ordinal + 1;
        }
        mut duplicate := index + 1;
        while duplicate < len(functions) {
            if std.str_eq(functions[duplicate].abi_id, value.abi_id) == 1 {
                return mir_function_abi_table_validation(0, "abi_duplicate_conflicting_record", ctx);
            }
            duplicate = duplicate + 1;
        }
        index = index + 1;
    }

    index = 0;
    while index < len(parameters) {
        mut value := parameters[index];
        mut classification := mir_abi_classification_by_id(table, value.classification_id, ctx);
        if mir_function_abi_by_id(table, value.abi_id, ctx).found == 0 || classification.found == 0 {
            return mir_function_abi_table_validation(0, "abi_unknown_id", ctx);
        }
        if value.ordinal < 0 || value.hidden != 0 || mir_abi_passing_mode_is_valid(value.passing_mode) == 0 ||
           std.str_eq(classification.value.position, "parameter") == 0 ||
           std.str_eq(classification.value.layout_id, value.layout_id) == 0
        {
            return mir_function_abi_table_validation(0, "abi_impossible_placement", ctx);
        }
        if len(value.resource_id) != 0 && resource.mir_resource_by_id(resource_table, value.resource_id, ctx).found == 0 {
            return mir_function_abi_table_validation(0, "abi_unknown_layout_or_resource_id", ctx);
        }
        index = index + 1;
    }

    index = 0;
    while index < len(results) {
        mut value := results[index];
        mut classification := mir_abi_classification_by_id(table, value.classification_id, ctx);
        if mir_function_abi_by_id(table, value.abi_id, ctx).found == 0 || classification.found == 0 {
            return mir_function_abi_table_validation(0, "abi_unknown_id", ctx);
        }
        if value.ordinal < 0 || mir_abi_passing_mode_is_valid(value.passing_mode) == 0 ||
           std.str_eq(classification.value.layout_id, value.layout_id) == 0
        {
            return mir_function_abi_table_validation(0, "abi_impossible_placement", ctx);
        }
        if value.hidden == 1 {
            if std.str_eq(classification.value.position, "hidden_result") == 0 ||
               std.str_eq(value.passing_mode, "hidden_pointer") == 0
            {
                return mir_function_abi_table_validation(0, "abi_invalid_hidden_result", ctx);
            }
        } else if value.hidden != 0 || std.str_eq(classification.value.position, "result") == 0 {
            return mir_function_abi_table_validation(0, "abi_invalid_hidden_result", ctx);
        }
        if len(value.resource_id) != 0 && resource.mir_resource_by_id(resource_table, value.resource_id, ctx).found == 0 {
            return mir_function_abi_table_validation(0, "abi_unknown_layout_or_resource_id", ctx);
        }
        index = index + 1;
    }

    index = 0;
    while index < len(calls) {
        mut value := calls[index];
        if mir_function_abi_by_id(table, value.expected_abi_id, ctx).found == 0 ||
           mir_function_abi_by_id(table, value.actual_abi_id, ctx).found == 0
        {
            return mir_function_abi_table_validation(0, "abi_unknown_id", ctx);
        }
        if std.str_eq(value.target_id, table.target_id) == 0 ||
           std.str_eq(value.target_triple, table.target_triple) == 0
        {
            return mir_function_abi_table_validation(0, "abi_target_mismatch", ctx);
        }
        mut compatibility := mir_validate_abi_compatibility(table, value.expected_abi_id, value.actual_abi_id, ctx);
        if compatibility.compatible != value.signature_compatible {
            return mir_function_abi_table_validation(0, "abi_signature_mismatch", ctx);
        }
        if mir_abi_has_call_reference(table, value.call_plan_id, ctx) == 0 {
            return mir_function_abi_table_validation(0, "abi_metadata_inconsistent_with_canonical_mir", ctx);
        }
        index = index + 1;
    }

    index = 0;
    while index < len(frames) {
        mut value := frames[index];
        if value.fixed_size_bytes < 0 || mir_abi_power_of_two(value.alignment_bytes) == 0 ||
           (len(value.dynamic_size_value_id) != 0 && value.bounded != 1)
        {
            return mir_function_abi_table_validation(0, "abi_impossible_placement", ctx);
        }
        if std.str_eq(value.target_id, table.target_id) == 0 ||
           std.str_eq(value.target_triple, table.target_triple) == 0
        {
            return mir_function_abi_table_validation(0, "abi_target_mismatch", ctx);
        }
        if mir_abi_has_frame_reference(table, value.frame_plan_id, ctx) == 0 {
            return mir_function_abi_table_validation(0, "abi_metadata_inconsistent_with_canonical_mir", ctx);
        }
        index = index + 1;
    }

    index = 0;
    while index < len(decisions) {
        mut value := decisions[index];
        mut compatibility := mir_validate_abi_compatibility(table, value.expected_abi_id, value.actual_abi_id, ctx);
        if compatibility.compatible != value.compatible || std.str_eq(compatibility.reason_code, value.reason_code) == 0 {
            return mir_function_abi_table_validation(0, "abi_signature_mismatch", ctx);
        }
        index = index + 1;
    }

    index = 0;
    while index < len(references) {
        mut value := references[index];
        if mir_abi_field_is_safe(value.reference_id, 0) == 0 ||
           (len(value.mir_function_id) == 0 && len(value.mir_call_id) == 0 && len(value.mir_result_id) == 0)
        {
            return mir_function_abi_table_validation(0, "abi_metadata_inconsistent_with_canonical_mir", ctx);
        }
        if len(value.abi_id) != 0 && mir_function_abi_by_id(table, value.abi_id, ctx).found == 0 {
            return mir_function_abi_table_validation(0, "abi_unknown_id", ctx);
        }
        if len(value.call_plan_id) != 0 && mir_abi_has_call_plan_id(table, value.call_plan_id, ctx) == 0 {
            return mir_function_abi_table_validation(0, "abi_unknown_id", ctx);
        }
        if len(value.frame_plan_id) != 0 && mir_abi_has_frame_plan_id(table, value.frame_plan_id, ctx) == 0 {
            return mir_function_abi_table_validation(0, "abi_unknown_id", ctx);
        }
        index = index + 1;
    }

    return mir_function_abi_table_validation(1, "abi_table_valid", ctx);
}

func mir_abi_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

// Immutable, deterministic compiler-produced ABI table serialization.
func mir_serialize_function_abi_authority_table_for_request(table: MirFunctionAbiAuthorityTable[ctx], layout_table: layout.MirLayoutTable[ctx], resource_table: resource.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_function_abi_authority_table_validate(table, layout_table, resource_table, ctx);
    if validation.valid == 0 {
        mut invalid := "abi_authority_format: invalid\nabi_authority_reason: ";
        invalid = std.Concat(invalid, validation.reason_code);
        invalid = std.Concat(invalid, "\n");
        return std.Clone(ctx, invalid);
    }
    mut functions: std.Vector[MirFunctionAbiIdentity[ctx], ctx] := ctx[table.functions];
    mut classifications: std.Vector[MirAbiValueClassification[ctx], ctx] := ctx[table.classifications];
    mut parameters: std.Vector[MirAbiParameterPlacement[ctx], ctx] := ctx[table.parameter_placements];
    mut results: std.Vector[MirAbiResultPlacement[ctx], ctx] := ctx[table.result_placements];
    mut calls: std.Vector[MirAbiCallSitePlan[ctx], ctx] := ctx[table.call_plans];
    mut frames: std.Vector[MirDynamicFramePlan[ctx], ctx] := ctx[table.frame_plans];
    mut decisions: std.Vector[MirAbiCompatibilityDecision[ctx], ctx] := ctx[table.compatibility_decisions];
    mut references: std.Vector[MirAbiMirReference[ctx], ctx] := ctx[table.mir_references];
    mut output := "abi_authority_format: gust.compiler_function_abi_authority_table.v1\n";
    output = mir_abi_append_field(output, "abi_authority_target_id", table.target_id, ctx);
    output = mir_abi_append_field(output, "abi_authority_target_triple", table.target_triple, ctx);
    output = mir_abi_append_field(output, "abi_function_count", std.FormatInt(len(functions)), ctx);
    output = mir_abi_append_field(output, "abi_classification_count", std.FormatInt(len(classifications)), ctx);
    output = mir_abi_append_field(output, "abi_parameter_placement_count", std.FormatInt(len(parameters)), ctx);
    output = mir_abi_append_field(output, "abi_result_placement_count", std.FormatInt(len(results)), ctx);
    output = mir_abi_append_field(output, "abi_call_plan_count", std.FormatInt(len(calls)), ctx);
    output = mir_abi_append_field(output, "abi_frame_plan_count", std.FormatInt(len(frames)), ctx);
    output = mir_abi_append_field(output, "abi_compatibility_count", std.FormatInt(len(decisions)), ctx);
    output = mir_abi_append_field(output, "abi_mir_reference_count", std.FormatInt(len(references)), ctx);
    return std.Clone(ctx, output);
}
