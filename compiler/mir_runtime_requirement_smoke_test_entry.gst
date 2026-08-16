// Phase 17.3 native smoke: compiler-produced runtime requirements carried
// through canonical MIR references and the deduplicated request-side table.
//
// The positive path proves three canonical MIR runtime operations resolve to two
// compiler-owned requirements across two call shapes. The negative paths prove
// the validator rejects missing, unused, and version-incompatible ownership
// instead of letting a worker, driver, or linker invent it.

import "mir_runtime_boundary_authority.gst" as runtime;
import "mir_native_backend_runtime_request.gst" as runtime_request;

func smoke_target_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func smoke_make_symbol(
    helper_id: str,
    spelling: str,
    signature: str,
    component_id: str,
    runtime_abi_id: str,
    target_id: str,
    ordinal: int,
    ctx: &Arena
) runtime.MirRuntimeSymbolIdentity[ctx] {
    mut symbol: runtime.MirRuntimeSymbolIdentity[ctx];
    symbol.symbol_id = runtime.mir_runtime_symbol_identity_id(helper_id, "gust-runtime-symbol-v1", target_id, ordinal, ctx);
    symbol.helper_id = helper_id;
    symbol.external_spelling = spelling;
    symbol.symbol_version = "gust-runtime-symbol-v1";
    symbol.component_id = component_id;
    symbol.runtime_abi_id = runtime_abi_id;
    mut function_abi_id := "function_abi:runtime:";
    function_abi_id = std.Concat(function_abi_id, spelling);
    function_abi_id = std.Concat(function_abi_id, ":");
    function_abi_id = std.Concat(function_abi_id, signature);
    function_abi_id = std.Concat(function_abi_id, ":gust_canonical_v1");
    symbol.function_abi_id = std.Clone(ctx, function_abi_id);
    symbol.calling_convention_id = "gust_canonical_v1";
    symbol.layout_id = "layout:type:gust:i32";
    symbol.resource_operation_id = "none_scalar_runtime_operation";
    symbol.target_id = target_id;
    symbol.target_triple = "x86_64-unknown-linux-gnu";
    symbol.required = 1;
    symbol.visibility = "public_runtime_import";
    symbol.linkage = "external_static_runtime_package";
    symbol.compatibility_policy = "exact_major_compatible_minor_range_1_1";
    return symbol;
}

func smoke_make_requirement(
    program_id: str,
    mir_operation_id: str,
    symbol: runtime.MirRuntimeSymbolIdentity[ctx],
    package_id: str,
    call_kind: str,
    ordinal: int,
    ctx: &Arena
) runtime.MirRuntimeRequirement[ctx] {
    mut requirement: runtime.MirRuntimeRequirement[ctx];
    requirement.requirement_id = runtime.mir_runtime_requirement_id(program_id, symbol.helper_id, ordinal, ctx);
    requirement.program_id = program_id;
    requirement.mir_operation_id = mir_operation_id;
    requirement.helper_id = symbol.helper_id;
    requirement.runtime_abi_id = symbol.runtime_abi_id;
    requirement.component_id = symbol.component_id;
    requirement.package_id = package_id;
    requirement.required = 1;
    requirement.symbol_id = symbol.symbol_id;
    requirement.required_version_min = 1;
    requirement.required_version_max = 1;
    requirement.target_id = symbol.target_id;
    requirement.layout_id = symbol.layout_id;
    requirement.resource_operation_id = symbol.resource_operation_id;
    requirement.function_abi_id = symbol.function_abi_id;
    requirement.call_kind = call_kind;
    requirement.package_mandatory = 0;
    return requirement;
}

func smoke_make_reference(
    mir_operation_id: str,
    requirement: runtime.MirRuntimeRequirement[ctx],
    target_applicability: str,
    ordinal: int,
    ctx: &Arena
) runtime.MirRuntimeMirReference[ctx] {
    mut reference: runtime.MirRuntimeMirReference[ctx];
    reference.reference_id = runtime.mir_runtime_mir_reference_id(mir_operation_id, requirement.helper_id, ordinal, ctx);
    reference.mir_operation_id = mir_operation_id;
    reference.helper_id = requirement.helper_id;
    reference.requirement_id = requirement.requirement_id;
    reference.symbol_id = requirement.symbol_id;
    reference.runtime_abi_id = requirement.runtime_abi_id;
    reference.required_version_min = requirement.required_version_min;
    reference.required_version_max = requirement.required_version_max;
    reference.target_applicability = target_applicability;
    reference.layout_id = requirement.layout_id;
    reference.resource_operation_id = requirement.resource_operation_id;
    reference.function_abi_id = requirement.function_abi_id;
    reference.call_kind = requirement.call_kind;
    return reference;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_id := smoke_target_id();
    mut applicability := "all_declared_host_targets_from_phase14_target_authority";
    mut program_id := "program:phase17_3_runtime_requirement_smoke";
    mut table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);

    mut abi: runtime.MirRuntimeAbiIdentity[ctx];
    abi.runtime_abi_id = runtime.mir_runtime_abi_identity_id("runtime:gust", target_id, 0, &ctx);
    abi.abi_version = "gust-runtime-abi-v1";
    abi.compatible_version_min = 1;
    abi.compatible_version_max = 1;
    abi.target_id = target_id;
    abi.target_triple = "x86_64-unknown-linux-gnu";
    abi.calling_convention_id = "gust_canonical_v1";
    abi.layout_authority_id = "phase14_compiler_owned_type_and_target_layout";
    abi.function_abi_authority_id = "phase16_compiler_owned_function_abi";
    abi.resource_authority_id = "phase15_compiler_owned_resource_operations";
    abi.visibility_policy = "default_hidden_selected_exports_public";
    abi.linkage_policy = "static_runtime_package_import";
    table = runtime.mir_runtime_table_with_abi(table, abi, &ctx);

    mut component: runtime.MirRuntimeComponentIdentity[ctx];
    component.component_id = runtime.mir_runtime_component_identity_id("stable_runtime_library_function", target_id, 0, &ctx);
    component.component_kind = "stable_runtime_library_function";
    component.source_path = "src/runtime/approved_scalar_imports.c";
    component.object_identity = "runtime:approved_scalar_imports";
    component.target_id = target_id;
    table = runtime.mir_runtime_table_with_component(table, component, &ctx);

    mut package: runtime.MirRuntimePackageIdentity[ctx];
    package.package_id = runtime.mir_runtime_package_identity_id(target_id, "gust-runtime-package-v1", 0, &ctx);
    package.package_version = "gust-runtime-package-v1";
    package.target_id = target_id;
    package.available = 1;
    table = runtime.mir_runtime_table_with_package(table, package, &ctx);

    mut helper_one: runtime.MirRuntimeHelperIdentity[ctx];
    helper_one.helper_id = runtime.mir_runtime_helper_identity_id("tiny_host_add_one_i32", target_id, 0, &ctx);
    helper_one.operation_id = "tiny_host_add_one_i32";
    helper_one.symbol_identity = "tiny_host_add_one_i32";
    helper_one.source_location = "src/runtime/approved_scalar_imports.c:5";
    helper_one.target_applicability = applicability;
    table = runtime.mir_runtime_table_with_helper(table, helper_one, &ctx);

    mut classification_one: runtime.MirRuntimeHelperClassification[ctx];
    classification_one.classification_id = runtime.mir_runtime_classification_id(helper_one.helper_id, 0, &ctx);
    classification_one.helper_id = helper_one.helper_id;
    classification_one.classification = "stable_runtime_library_function";
    classification_one.component_id = component.component_id;
    classification_one.reason_code = "runtime_helper_classified_stable_library_import";
    table = runtime.mir_runtime_table_with_classification(table, classification_one, &ctx);

    mut helper_two: runtime.MirRuntimeHelperIdentity[ctx];
    helper_two.helper_id = runtime.mir_runtime_helper_identity_id("tiny_host_add_i32", target_id, 1, &ctx);
    helper_two.operation_id = "tiny_host_add_i32";
    helper_two.symbol_identity = "tiny_host_add_i32";
    helper_two.source_location = "src/runtime/approved_scalar_imports.c:9";
    helper_two.target_applicability = applicability;
    table = runtime.mir_runtime_table_with_helper(table, helper_two, &ctx);

    mut classification_two: runtime.MirRuntimeHelperClassification[ctx];
    classification_two.classification_id = runtime.mir_runtime_classification_id(helper_two.helper_id, 1, &ctx);
    classification_two.helper_id = helper_two.helper_id;
    classification_two.classification = "stable_runtime_library_function";
    classification_two.component_id = component.component_id;
    classification_two.reason_code = "runtime_helper_classified_stable_library_import";
    table = runtime.mir_runtime_table_with_classification(table, classification_two, &ctx);

    mut symbol_one := smoke_make_symbol(helper_one.helper_id, "tiny_host_add_one_i32", "i32_to_i32", component.component_id, abi.runtime_abi_id, target_id, 0, &ctx);
    table = runtime.mir_runtime_table_with_symbol(table, symbol_one, &ctx);
    mut symbol_two := smoke_make_symbol(helper_two.helper_id, "tiny_host_add_i32", "i32_i32_to_i32", component.component_id, abi.runtime_abi_id, target_id, 1, &ctx);
    table = runtime.mir_runtime_table_with_symbol(table, symbol_two, &ctx);

    // Two call shapes, three canonical MIR operations, two requirements. The
    // repeated direct call is what the request-side table deduplicates.
    mut requirement_one := smoke_make_requirement(program_id, "mir_op:call:add_one:0", symbol_one, package.package_id, "direct_call", 0, &ctx);
    table = runtime.mir_runtime_table_with_requirement(table, requirement_one, &ctx);
    mut requirement_two := smoke_make_requirement(program_id, "mir_op:cleanup:add:0", symbol_two, package.package_id, "cleanup_or_destructor", 1, &ctx);
    table = runtime.mir_runtime_table_with_requirement(table, requirement_two, &ctx);

    table = runtime.mir_runtime_table_with_mir_reference(table, smoke_make_reference("mir_op:call:add_one:0", requirement_one, applicability, 0, &ctx), &ctx);
    table = runtime.mir_runtime_table_with_mir_reference(table, smoke_make_reference("mir_op:call:add_one:1", requirement_one, applicability, 1, &ctx), &ctx);
    table = runtime.mir_runtime_table_with_mir_reference(table, smoke_make_reference("mir_op:cleanup:add:0", requirement_two, applicability, 2, &ctx), &ctx);

    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, &ctx);
    if validation.valid == 0 { os.Exit(1); }

    // Every runtime-facing operation resolves to exactly one requirement.
    mut first := runtime.mir_runtime_requirement_for(table, "mir_op:call:add_one:0", &ctx);
    if first.found == 0 || std.str_eq(first.value.requirement_id, requirement_one.requirement_id) == 0 { os.Exit(2); }
    mut second := runtime.mir_runtime_requirement_for(table, "mir_op:call:add_one:1", &ctx);
    if second.found == 0 || std.str_eq(second.value.requirement_id, requirement_one.requirement_id) == 0 { os.Exit(3); }
    mut third := runtime.mir_runtime_requirement_for(table, "mir_op:cleanup:add:0", &ctx);
    if third.found == 0 || std.str_eq(third.value.requirement_id, requirement_two.requirement_id) == 0 { os.Exit(4); }
    if std.str_eq(third.value.call_kind, "cleanup_or_destructor") == 0 { os.Exit(5); }

    // An operation the compiler never described has no requirement to consume.
    mut absent := runtime.mir_runtime_requirement_for(table, "mir_op:call:not_declared:0", &ctx);
    if absent.found == 1 { os.Exit(6); }

    mut reference_query := runtime.mir_runtime_mir_reference_for(table, "mir_op:call:add_one:1", &ctx);
    if reference_query.found == 0 || std.str_eq(reference_query.value.call_kind, "direct_call") == 0 { os.Exit(7); }

    // The deduplicated table carries one row per symbol, not one per operation.
    mut deduplicated := runtime.mir_runtime_requirement_table(table, program_id, &ctx);
    mut deduplicated_rows: std.Vector[runtime.MirRuntimeRequirement[ctx], ctx] := ctx[deduplicated];
    if len(deduplicated_rows) != 2 { os.Exit(8); }
    if std.str_eq(deduplicated_rows[0].symbol_id, symbol_one.symbol_id) == 0 { os.Exit(9); }
    if std.str_eq(deduplicated_rows[1].symbol_id, symbol_two.symbol_id) == 0 { os.Exit(10); }

    mut other_program := runtime.mir_runtime_requirement_table(table, "program:absent", &ctx);
    mut other_rows: std.Vector[runtime.MirRuntimeRequirement[ctx], ctx] := ctx[other_program];
    if len(other_rows) != 0 { os.Exit(11); }

    // The request envelope exposes the same compiler-owned answers.
    mut serialized := runtime.mir_serialize_runtime_boundary_authority_table_for_request(table, &ctx);
    if std.str_find(serialized, "runtime_requirement_call_kind: direct_call") == 0 - 1 { os.Exit(12); }
    if std.str_find(serialized, "runtime_mir_reference_requirement_id: ") == 0 - 1 { os.Exit(13); }

    // Rejection: a canonical MIR runtime operation without a requirement.
    mut missing_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    missing_table = runtime.mir_runtime_table_with_abi(missing_table, abi, &ctx);
    missing_table = runtime.mir_runtime_table_with_component(missing_table, component, &ctx);
    missing_table = runtime.mir_runtime_table_with_package(missing_table, package, &ctx);
    missing_table = runtime.mir_runtime_table_with_helper(missing_table, helper_one, &ctx);
    missing_table = runtime.mir_runtime_table_with_classification(missing_table, classification_one, &ctx);
    missing_table = runtime.mir_runtime_table_with_symbol(missing_table, symbol_one, &ctx);
    missing_table = runtime.mir_runtime_table_with_mir_reference(missing_table, smoke_make_reference("mir_op:call:add_one:0", requirement_one, applicability, 0, &ctx), &ctx);
    mut missing_validation := runtime.mir_runtime_boundary_authority_table_validate(missing_table, &ctx);
    if missing_validation.valid == 1 || std.str_eq(missing_validation.reason_code, "runtime_requirement_missing_for_mir_operation") == 0 { os.Exit(14); }

    // Rejection: a requirement canonical MIR never reaches and no package mandate.
    mut unused_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    unused_table = runtime.mir_runtime_table_with_abi(unused_table, abi, &ctx);
    unused_table = runtime.mir_runtime_table_with_component(unused_table, component, &ctx);
    unused_table = runtime.mir_runtime_table_with_package(unused_table, package, &ctx);
    unused_table = runtime.mir_runtime_table_with_helper(unused_table, helper_one, &ctx);
    unused_table = runtime.mir_runtime_table_with_classification(unused_table, classification_one, &ctx);
    unused_table = runtime.mir_runtime_table_with_symbol(unused_table, symbol_one, &ctx);
    unused_table = runtime.mir_runtime_table_with_requirement(unused_table, requirement_one, &ctx);
    mut unused_validation := runtime.mir_runtime_boundary_authority_table_validate(unused_table, &ctx);
    if unused_validation.valid == 1 || std.str_eq(unused_validation.reason_code, "runtime_requirement_unused_without_package_mandate") == 0 { os.Exit(15); }

    // The same unused requirement is legal once declared package-mandatory.
    mut mandatory_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    mandatory_table = runtime.mir_runtime_table_with_abi(mandatory_table, abi, &ctx);
    mandatory_table = runtime.mir_runtime_table_with_component(mandatory_table, component, &ctx);
    mandatory_table = runtime.mir_runtime_table_with_package(mandatory_table, package, &ctx);
    mandatory_table = runtime.mir_runtime_table_with_helper(mandatory_table, helper_one, &ctx);
    mandatory_table = runtime.mir_runtime_table_with_classification(mandatory_table, classification_one, &ctx);
    mandatory_table = runtime.mir_runtime_table_with_symbol(mandatory_table, symbol_one, &ctx);
    mut mandatory_requirement := smoke_make_requirement(program_id, "mir_op:package_mandatory:0", symbol_one, package.package_id, "runtime_module_call", 0, &ctx);
    mandatory_requirement.package_mandatory = 1;
    mandatory_table = runtime.mir_runtime_table_with_requirement(mandatory_table, mandatory_requirement, &ctx);
    mut mandatory_validation := runtime.mir_runtime_boundary_authority_table_validate(mandatory_table, &ctx);
    if mandatory_validation.valid == 0 { os.Exit(16); }

    // Rejection: a required version range outside the frozen ABI range.
    mut version_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    version_table = runtime.mir_runtime_table_with_abi(version_table, abi, &ctx);
    version_table = runtime.mir_runtime_table_with_component(version_table, component, &ctx);
    version_table = runtime.mir_runtime_table_with_package(version_table, package, &ctx);
    version_table = runtime.mir_runtime_table_with_helper(version_table, helper_one, &ctx);
    version_table = runtime.mir_runtime_table_with_classification(version_table, classification_one, &ctx);
    version_table = runtime.mir_runtime_table_with_symbol(version_table, symbol_one, &ctx);
    mut incompatible := smoke_make_requirement(program_id, "mir_op:call:add_one:0", symbol_one, package.package_id, "direct_call", 0, &ctx);
    incompatible.required_version_max = 2;
    incompatible.package_mandatory = 1;
    version_table = runtime.mir_runtime_table_with_requirement(version_table, incompatible, &ctx);
    mut version_validation := runtime.mir_runtime_boundary_authority_table_validate(version_table, &ctx);
    if version_validation.valid == 1 || std.str_eq(version_validation.reason_code, "runtime_requirement_symbol_version_incompatible") == 0 { os.Exit(17); }

    // Rejection: a requirement whose carried layout diverges from its symbol.
    mut layout_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    layout_table = runtime.mir_runtime_table_with_abi(layout_table, abi, &ctx);
    layout_table = runtime.mir_runtime_table_with_component(layout_table, component, &ctx);
    layout_table = runtime.mir_runtime_table_with_package(layout_table, package, &ctx);
    layout_table = runtime.mir_runtime_table_with_helper(layout_table, helper_one, &ctx);
    layout_table = runtime.mir_runtime_table_with_classification(layout_table, classification_one, &ctx);
    layout_table = runtime.mir_runtime_table_with_symbol(layout_table, symbol_one, &ctx);
    mut mismatched := smoke_make_requirement(program_id, "mir_op:call:add_one:0", symbol_one, package.package_id, "direct_call", 0, &ctx);
    mismatched.layout_id = "layout:type:gust:i64";
    mismatched.package_mandatory = 1;
    layout_table = runtime.mir_runtime_table_with_requirement(layout_table, mismatched, &ctx);
    mut layout_validation := runtime.mir_runtime_boundary_authority_table_validate(layout_table, &ctx);
    if layout_validation.valid == 1 || std.str_eq(layout_validation.reason_code, "runtime_requirement_target_or_layout_mismatch") == 0 { os.Exit(18); }

    // Rejection: a requirement naming a symbol that is not compiler-owned.
    mut unknown_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    unknown_table = runtime.mir_runtime_table_with_abi(unknown_table, abi, &ctx);
    unknown_table = runtime.mir_runtime_table_with_component(unknown_table, component, &ctx);
    unknown_table = runtime.mir_runtime_table_with_package(unknown_table, package, &ctx);
    unknown_table = runtime.mir_runtime_table_with_helper(unknown_table, helper_one, &ctx);
    unknown_table = runtime.mir_runtime_table_with_classification(unknown_table, classification_one, &ctx);
    unknown_table = runtime.mir_runtime_table_with_symbol(unknown_table, symbol_one, &ctx);
    mut unknown_symbol := smoke_make_requirement(program_id, "mir_op:call:add_one:0", symbol_one, package.package_id, "direct_call", 0, &ctx);
    unknown_symbol.symbol_id = "runtime_symbol:v1:helper=not_compiler_owned";
    unknown_symbol.package_mandatory = 1;
    unknown_table = runtime.mir_runtime_table_with_requirement(unknown_table, unknown_symbol, &ctx);
    mut unknown_validation := runtime.mir_runtime_boundary_authority_table_validate(unknown_table, &ctx);
    if unknown_validation.valid == 1 || std.str_eq(unknown_validation.reason_code, "runtime_requirement_unknown_helper_or_symbol") == 0 { os.Exit(19); }

    // Keep the request module in the generic producer graph without requiring a
    // native driver, worker, object, linker, or output artifact in Level 1.
    if std.str_eq("runtime_request", "runtime_request") == 0 { os.Exit(20); }
    os.LogStr("SUCCESS: Phase 17.3 runtime requirement smoke passed");
}
