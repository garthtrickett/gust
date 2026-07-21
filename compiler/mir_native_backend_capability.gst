import "mir.gst" as mir;

// Phase 10 compiler-owned native-backend capability validation.
//
// This module is backend-neutral. It consumes a structurally valid canonical
// whole-program MIR bundle plus an ordered typed requirement plan and an
// explicit compiler-owned capability set. It does not discover or invoke a
// driver, emit an object, link an executable, touch output paths, or provide a
// fallback route.
type MirNativeBackendRequirementKind enum {
    Operation,
    TypeOrAbi,
    RuntimeImport,
    TargetRequirement
}

type MirNativeBackendCapabilityClassification enum {
    Supported,
    UnsupportedOperation,
    UnsupportedTypeOrAbi,
    UnsupportedRuntimeImport,
    UnsupportedTargetRequirement,
    InvalidCompilerMir
}

type MirNativeBackendRequirement[ctx] struct {
    kind: MirNativeBackendRequirementKind,
    module_path: str,
    function_name: str,
    block_label: str,
    ordinal: int,
    feature: str
}

type MirNativeBackendCapabilityPlan[ctx] struct {
    requirements: Index[std.Vector[MirNativeBackendRequirement[ctx], ctx], ctx]
}

type MirNativeBackendCapabilitySet[ctx] struct {
    operations: Index[std.Vector[str, ctx], ctx],
    types_and_abis: Index[std.Vector[str, ctx], ctx],
    runtime_imports: Index[std.Vector[str, ctx], ctx],
    target_requirements: Index[std.Vector[str, ctx], ctx]
}

type MirNativeBackendCapabilityResult[ctx] struct {
    classification: MirNativeBackendCapabilityClassification,
    requirement_kind: MirNativeBackendRequirementKind,
    module_path: str,
    function_name: str,
    block_label: str,
    ordinal: int,
    feature: str,
    detail: str
}

// Phase 13 compiler-owned decision for the generic source-to-canonical-MIR
// native route. It is created before driver discovery or artifact access and
// remains independent of any worker implementation.
type MirNativeBackendRouteDecisionKind enum {
    Supported,
    Deferred,
    SourceOrTypeFailure
}

type MirNativeBackendRouteDecision[ctx] struct {
    kind: MirNativeBackendRouteDecisionKind,
    capability_id: str,
    decision_owner: str,
    reason_code: str,
    source_path: str,
    line: int,
    column: int,
    expected_failure_stage: str
}

func mir_native_backend_empty_requirement_vector(ctx: &Arena) Index[std.Vector[MirNativeBackendRequirement[ctx], ctx], ctx] {
    mut requirements: std.Vector[MirNativeBackendRequirement[ctx], ctx] := std.VectorNew(ctx);
    mut requirements_idx: Index[std.Vector[MirNativeBackendRequirement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(requirements_idx, requirements);
    return requirements_idx;
}

func mir_native_backend_empty_string_vector(ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut values: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_native_backend_make_capability_plan(ctx: &Arena) MirNativeBackendCapabilityPlan[ctx] {
    mut plan: MirNativeBackendCapabilityPlan[ctx];
    plan.requirements = mir_native_backend_empty_requirement_vector(ctx);
    return plan;
}

func mir_native_backend_make_capability_set(ctx: &Arena) MirNativeBackendCapabilitySet[ctx] {
    mut capabilities: MirNativeBackendCapabilitySet[ctx];
    capabilities.operations = mir_native_backend_empty_string_vector(ctx);
    capabilities.types_and_abis = mir_native_backend_empty_string_vector(ctx);
    capabilities.runtime_imports = mir_native_backend_empty_string_vector(ctx);
    capabilities.target_requirements = mir_native_backend_empty_string_vector(ctx);
    return capabilities;
}

func mir_native_backend_make_requirement(kind_tag: int, module_path: str, function_name: str, block_label: str, ordinal: int, feature: str, ctx: &Arena) MirNativeBackendRequirement[ctx] {
    mut requirement: MirNativeBackendRequirement[ctx];
    unsafe {
        requirement.kind.tag = kind_tag;
    }
    requirement.module_path = std.Clone(ctx, module_path);
    requirement.function_name = std.Clone(ctx, function_name);
    requirement.block_label = std.Clone(ctx, block_label);
    requirement.ordinal = ordinal;
    requirement.feature = std.Clone(ctx, feature);
    return requirement;
}

func mir_native_backend_capability_plan_with_requirement(plan: MirNativeBackendCapabilityPlan[ctx], requirement: MirNativeBackendRequirement[ctx], ctx: &Arena) MirNativeBackendCapabilityPlan[ctx] {
    mut updated := plan;
    mut requirements: std.Vector[MirNativeBackendRequirement[ctx], ctx] := ctx[updated.requirements];
    requirements.Push(requirement);
    ctx.Set(updated.requirements, requirements);
    return updated;
}

func mir_native_backend_capability_set_with_operation(capabilities: MirNativeBackendCapabilitySet[ctx], operation: str, ctx: &Arena) MirNativeBackendCapabilitySet[ctx] {
    mut updated := capabilities;
    mut operations: std.Vector[str, ctx] := ctx[updated.operations];
    operations.Push(std.Clone(ctx, operation));
    ctx.Set(updated.operations, operations);
    return updated;
}

func mir_native_backend_capability_set_with_type_or_abi(capabilities: MirNativeBackendCapabilitySet[ctx], type_or_abi: str, ctx: &Arena) MirNativeBackendCapabilitySet[ctx] {
    mut updated := capabilities;
    mut types_and_abis: std.Vector[str, ctx] := ctx[updated.types_and_abis];
    types_and_abis.Push(std.Clone(ctx, type_or_abi));
    ctx.Set(updated.types_and_abis, types_and_abis);
    return updated;
}

func mir_native_backend_capability_set_with_runtime_import(capabilities: MirNativeBackendCapabilitySet[ctx], runtime_import: str, ctx: &Arena) MirNativeBackendCapabilitySet[ctx] {
    mut updated := capabilities;
    mut runtime_imports: std.Vector[str, ctx] := ctx[updated.runtime_imports];
    runtime_imports.Push(std.Clone(ctx, runtime_import));
    ctx.Set(updated.runtime_imports, runtime_imports);
    return updated;
}

func mir_native_backend_capability_set_with_target_requirement(capabilities: MirNativeBackendCapabilitySet[ctx], target_requirement: str, ctx: &Arena) MirNativeBackendCapabilitySet[ctx] {
    mut updated := capabilities;
    mut target_requirements: std.Vector[str, ctx] := ctx[updated.target_requirements];
    target_requirements.Push(std.Clone(ctx, target_requirement));
    ctx.Set(updated.target_requirements, target_requirements);
    return updated;
}

func mir_native_backend_string_vector_contains(values_idx: Index[std.Vector[str, ctx], ctx], expected: str, ctx: &Arena) int {
    mut values: std.Vector[str, ctx] := ctx[values_idx];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index], expected) == 1 {
            return 1;
        }
        index = index + 1;
    }
    return 0;
}

func mir_native_backend_string_vector_is_valid(values_idx: Index[std.Vector[str, ctx], ctx], ctx: &Arena) int {
    mut values: std.Vector[str, ctx] := ctx[values_idx];
    mut index := 0;
    while index < len(values) {
        if mir.mir_program_bundle_field_is_safe(values[index], 0) == 0 {
            return 0;
        }

        mut prior_index := 0;
        while prior_index < index {
            if std.str_eq(values[prior_index], values[index]) == 1 {
                return 0;
            }
            prior_index = prior_index + 1;
        }

        index = index + 1;
    }
    return 1;
}

func mir_native_backend_capability_set_is_valid(capabilities: MirNativeBackendCapabilitySet[ctx], ctx: &Arena) int {
    if mir_native_backend_string_vector_is_valid(capabilities.operations, ctx) == 0 {
        return 0;
    }
    if mir_native_backend_string_vector_is_valid(capabilities.types_and_abis, ctx) == 0 {
        return 0;
    }
    if mir_native_backend_string_vector_is_valid(capabilities.runtime_imports, ctx) == 0 {
        return 0;
    }
    if mir_native_backend_string_vector_is_valid(capabilities.target_requirements, ctx) == 0 {
        return 0;
    }
    return 1;
}

func mir_native_backend_bundle_has_module(bundle: mir.MirProgramBundle[ctx], module_path: str, ctx: &Arena) int {
    mut modules: std.Vector[mir.MirProgramBundleModule[ctx], ctx] := ctx[bundle.modules];
    mut module_index := 0;
    while module_index < len(modules) {
        if std.str_eq(modules[module_index].module_path, module_path) == 1 {
            return 1;
        }
        module_index = module_index + 1;
    }
    return 0;
}

func mir_native_backend_bundle_has_imported_symbol(bundle: mir.MirProgramBundle[ctx], module_path: str, link_name: str, ctx: &Arena) int {
    mut modules: std.Vector[mir.MirProgramBundleModule[ctx], ctx] := ctx[bundle.modules];
    mut module_index := 0;
    while module_index < len(modules) {
        mut module := modules[module_index];
        if std.str_eq(module.module_path, module_path) == 1 {
            mut symbols: std.Vector[mir.MirProgramBundleSymbol[ctx], ctx] := ctx[module.symbols];
            mut symbol_index := 0;
            while symbol_index < len(symbols) {
                mut symbol := symbols[symbol_index];
                if symbol.linkage.tag == 2 && std.str_eq(symbol.link_name, link_name) == 1 {
                    return 1;
                }
                symbol_index = symbol_index + 1;
            }
        }
        module_index = module_index + 1;
    }
    return 0;
}

func mir_native_backend_make_capability_result(classification_tag: int, requirement_kind_tag: int, module_path: str, function_name: str, block_label: str, ordinal: int, feature: str, detail: str, ctx: &Arena) MirNativeBackendCapabilityResult[ctx] {
    mut result: MirNativeBackendCapabilityResult[ctx];
    unsafe {
        result.classification.tag = classification_tag;
        result.requirement_kind.tag = requirement_kind_tag;
    }
    result.module_path = std.Clone(ctx, module_path);
    result.function_name = std.Clone(ctx, function_name);
    result.block_label = std.Clone(ctx, block_label);
    result.ordinal = ordinal;
    result.feature = std.Clone(ctx, feature);
    result.detail = std.Clone(ctx, detail);
    return result;
}

func mir_native_backend_make_route_decision(kind_tag: int, reason_code: str, expected_failure_stage: str, ctx: &Arena) MirNativeBackendRouteDecision[ctx] {
    mut decision: MirNativeBackendRouteDecision[ctx];
    unsafe {
        decision.kind.tag = kind_tag;
    }
    decision.capability_id = std.Clone(
        ctx,
        "phase13_generic_source_to_mir"
    );
    decision.decision_owner = std.Clone(
        ctx,
        "compiler_generic_native_capability_planner"
    );
    decision.reason_code = std.Clone(ctx, reason_code);
    decision.source_path = std.Clone(ctx, "<source>");
    decision.line = 1;
    decision.column = 1;
    decision.expected_failure_stage = std.Clone(
        ctx,
        expected_failure_stage
    );
    return decision;
}

func mir_native_backend_supported_route_decision(ctx: &Arena) MirNativeBackendRouteDecision[ctx] {
    return mir_native_backend_make_route_decision(
        0,
        "supported",
        "none_supported",
        ctx
    );
}

func mir_native_backend_deferred_route_decision(reason_code: str, ctx: &Arena) MirNativeBackendRouteDecision[ctx] {
    return mir_native_backend_make_route_decision(
        1,
        reason_code,
        "before_driver_discovery",
        ctx
    );
}

func mir_native_backend_source_or_type_failure_route_decision(reason_code: str, ctx: &Arena) MirNativeBackendRouteDecision[ctx] {
    return mir_native_backend_make_route_decision(
        2,
        reason_code,
        "before_driver_discovery",
        ctx
    );
}

func mir_native_backend_route_decision_with_location(decision: MirNativeBackendRouteDecision[ctx], source_path: str, line: int, column: int, ctx: &Arena) MirNativeBackendRouteDecision[ctx] {
    mut located := decision;
    located.source_path = std.Clone(ctx, source_path);
    located.line = line;
    located.column = column;
    return located;
}

func mir_native_backend_route_decision_kind_name(decision: MirNativeBackendRouteDecision[ctx]) str {
    if decision.kind.tag == 0 {
        return "supported";
    }
    if decision.kind.tag == 1 {
        return "deferred";
    }
    if decision.kind.tag == 2 {
        return "source_or_type_failure";
    }
    return "invalid";
}

func mir_native_backend_route_decision_is_valid(decision: MirNativeBackendRouteDecision[ctx]) int {
    if decision.kind.tag != 0 &&
       decision.kind.tag != 1 &&
       decision.kind.tag != 2
    {
        return 0;
    }
    if std.str_eq(
        decision.capability_id,
        "phase13_generic_source_to_mir"
    ) == 0 {
        return 0;
    }
    if std.str_eq(
        decision.decision_owner,
        "compiler_generic_native_capability_planner"
    ) == 0 {
        return 0;
    }
    if len(decision.reason_code) == 0 ||
       len(decision.source_path) == 0 ||
       len(decision.expected_failure_stage) == 0 ||
       decision.line <= 0 ||
       decision.column <= 0
    {
        return 0;
    }

    if decision.kind.tag == 0 {
        if std.str_eq(decision.reason_code, "supported") == 0 ||
           std.str_eq(
               decision.expected_failure_stage,
               "none_supported"
           ) == 0
        {
            return 0;
        }
        return 1;
    }

    if std.str_eq(decision.reason_code, "supported") == 1 ||
       std.str_eq(
           decision.expected_failure_stage,
           "before_driver_discovery"
       ) == 0
    {
        return 0;
    }
    return 1;
}

func mir_native_backend_route_decision_line(decision: MirNativeBackendRouteDecision[ctx], ctx: &Arena) str {
    mut output := "gust_native_capability_decision: contract=gust.native_backend.capability.v1 decision=";
    output = std.Concat(
        output,
        mir_native_backend_route_decision_kind_name(decision)
    );
    output = std.Concat(output, " capability=");
    output = std.Concat(output, decision.capability_id);
    output = std.Concat(output, " owner=");
    output = std.Concat(output, decision.decision_owner);
    output = std.Concat(output, " reason_code=");
    output = std.Concat(output, decision.reason_code);
    output = std.Concat(output, " expected_failure_stage=");
    output = std.Concat(output, decision.expected_failure_stage);
    output = std.Concat(output, " source=");
    output = std.Concat(output, decision.source_path);
    output = std.Concat(output, " line=");
    output = std.Concat(output, std.FormatInt(decision.line));
    output = std.Concat(output, " column=");
    output = std.Concat(output, std.FormatInt(decision.column));
    return std.Clone(ctx, output);
}

func mir_native_backend_invalid_compiler_mir_result(module_path: str, function_name: str, block_label: str, ordinal: int, feature: str, detail: str, ctx: &Arena) MirNativeBackendCapabilityResult[ctx] {
    return mir_native_backend_make_capability_result(
        5,
        0,
        module_path,
        function_name,
        block_label,
        ordinal,
        feature,
        detail,
        ctx
    );
}

func mir_native_backend_requirement_is_structurally_valid(requirement: MirNativeBackendRequirement[ctx], expected_ordinal: int) int {
    if requirement.kind.tag < 0 || requirement.kind.tag > 3 {
        return 0;
    }
    if requirement.ordinal != expected_ordinal {
        return 0;
    }
    if mir.mir_program_bundle_field_is_safe(requirement.module_path, 0) == 0 {
        return 0;
    }
    if mir.mir_program_bundle_field_is_safe(requirement.function_name, 0) == 0 {
        return 0;
    }
    if mir.mir_program_bundle_field_is_safe(requirement.block_label, 1) == 0 {
        return 0;
    }
    if mir.mir_program_bundle_field_is_safe(requirement.feature, 0) == 0 {
        return 0;
    }
    return 1;
}

func mir_native_backend_validate_capabilities(bundle: mir.MirProgramBundle[ctx], plan: MirNativeBackendCapabilityPlan[ctx], capabilities: MirNativeBackendCapabilitySet[ctx], ctx: &Arena) MirNativeBackendCapabilityResult[ctx] {
    if mir.mir_program_bundle_is_valid(bundle, ctx) == 0 {
        return mir_native_backend_invalid_compiler_mir_result(
            "<bundle>",
            "<program>",
            "",
            0 - 1,
            "structural_validation",
            "compiler-generated canonical program MIR failed structural validation",
            ctx
        );
    }

    if mir_native_backend_capability_set_is_valid(capabilities, ctx) == 0 {
        return mir_native_backend_invalid_compiler_mir_result(
            "<capability-set>",
            "<program>",
            "",
            0 - 1,
            "capability_set",
            "compiler-owned native backend capability set is invalid",
            ctx
        );
    }

    mut requirements: std.Vector[MirNativeBackendRequirement[ctx], ctx] := ctx[plan.requirements];
    mut requirement_index := 0;
    while requirement_index < len(requirements) {
        mut requirement := requirements[requirement_index];

        if mir_native_backend_requirement_is_structurally_valid(requirement, requirement_index) == 0 {
            return mir_native_backend_invalid_compiler_mir_result(
                requirement.module_path,
                requirement.function_name,
                requirement.block_label,
                requirement_index,
                requirement.feature,
                "compiler-generated capability requirement context is invalid",
                ctx
            );
        }

        if mir_native_backend_bundle_has_module(bundle, requirement.module_path, ctx) == 0 {
            return mir_native_backend_invalid_compiler_mir_result(
                requirement.module_path,
                requirement.function_name,
                requirement.block_label,
                requirement.ordinal,
                requirement.feature,
                "capability requirement module is absent from the canonical program bundle",
                ctx
            );
        }

        mut supported := 0;
        if requirement.kind.tag == 0 {
            supported = mir_native_backend_string_vector_contains(
                capabilities.operations,
                requirement.feature,
                ctx
            );
        } else if requirement.kind.tag == 1 {
            supported = mir_native_backend_string_vector_contains(
                capabilities.types_and_abis,
                requirement.feature,
                ctx
            );
        } else if requirement.kind.tag == 2 {
            if mir_native_backend_bundle_has_imported_symbol(
                bundle,
                requirement.module_path,
                requirement.feature,
                ctx
            ) == 0 {
                return mir_native_backend_invalid_compiler_mir_result(
                    requirement.module_path,
                    requirement.function_name,
                    requirement.block_label,
                    requirement.ordinal,
                    requirement.feature,
                    "runtime import requirement is not represented by an imported-host bundle symbol",
                    ctx
                );
            }
            supported = mir_native_backend_string_vector_contains(
                capabilities.runtime_imports,
                requirement.feature,
                ctx
            );
        } else if requirement.kind.tag == 3 {
            supported = mir_native_backend_string_vector_contains(
                capabilities.target_requirements,
                requirement.feature,
                ctx
            );
        }

        if supported == 0 {
            if requirement.kind.tag == 0 {
                return mir_native_backend_make_capability_result(
                    1,
                    requirement.kind.tag,
                    requirement.module_path,
                    requirement.function_name,
                    requirement.block_label,
                    requirement.ordinal,
                    requirement.feature,
                    "native backend does not support this canonical MIR operation",
                    ctx
                );
            }
            if requirement.kind.tag == 1 {
                return mir_native_backend_make_capability_result(
                    2,
                    requirement.kind.tag,
                    requirement.module_path,
                    requirement.function_name,
                    requirement.block_label,
                    requirement.ordinal,
                    requirement.feature,
                    "native backend does not support this value type or function ABI",
                    ctx
                );
            }
            if requirement.kind.tag == 2 {
                return mir_native_backend_make_capability_result(
                    3,
                    requirement.kind.tag,
                    requirement.module_path,
                    requirement.function_name,
                    requirement.block_label,
                    requirement.ordinal,
                    requirement.feature,
                    "native backend does not support this runtime import",
                    ctx
                );
            }
            return mir_native_backend_make_capability_result(
                4,
                requirement.kind.tag,
                requirement.module_path,
                requirement.function_name,
                requirement.block_label,
                requirement.ordinal,
                requirement.feature,
                "native backend does not support this target requirement",
                ctx
            );
        }

        requirement_index = requirement_index + 1;
    }

    return mir_native_backend_make_capability_result(
        0,
        0,
        "<bundle>",
        "<program>",
        "",
        len(requirements),
        "all",
        "supported",
        ctx
    );
}

func mir_native_backend_capability_classification_name(classification: MirNativeBackendCapabilityClassification) str {
    if classification.tag == 0 {
        return "supported";
    }
    if classification.tag == 1 {
        return "unsupported_operation";
    }
    if classification.tag == 2 {
        return "unsupported_type_or_abi";
    }
    if classification.tag == 3 {
        return "unsupported_runtime_import";
    }
    if classification.tag == 4 {
        return "unsupported_target_requirement";
    }
    if classification.tag == 5 {
        return "invalid_compiler_mir";
    }
    return "invalid_classification";
}

func mir_native_backend_capability_diagnostic(result: MirNativeBackendCapabilityResult[ctx], ctx: &Arena) str {
    if result.classification.tag == 0 {
        return "Native backend capability validation: supported";
    }

    mut output := "Native backend capability error [";
    output = std.Concat(output, mir_native_backend_capability_classification_name(result.classification));
    output = std.Concat(output, "] module=");
    output = std.Concat(output, result.module_path);
    output = std.Concat(output, " function=");
    output = std.Concat(output, result.function_name);
    output = std.Concat(output, " block=");
    output = std.Concat(output, result.block_label);
    output = std.Concat(output, " requirement=");
    output = std.Concat(output, std.FormatInt(result.ordinal));
    output = std.Concat(output, " feature=");
    output = std.Concat(output, result.feature);
    output = std.Concat(output, ": ");
    output = std.Concat(output, result.detail);
    return std.Clone(ctx, output);
}
