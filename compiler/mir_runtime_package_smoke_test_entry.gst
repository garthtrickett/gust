// Phase 17.4 native smoke: explicit runtime package manifests and compiler-owned
// target-specific selection.
//
// The positive path builds a two-component static-archive manifest with a
// deterministic link order, proves selection is a compiler-owned compatibility
// decision, and proves the Phase 9G link plan follows the declared order. The
// negative paths prove ambiguous selection, wrong-target packages, duplicate
// components, missing mandatory symbols, incompatible ABI versions, undeclared
// members or system imports, and non-deterministic ordering are all rejected.

import "mir_runtime_boundary_authority.gst" as runtime;
import "mir_native_backend_runtime_request.gst" as runtime_request;

func package_target_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func package_make_component(
    kind: str,
    source_path: str,
    object_identity: str,
    target_id: str,
    ordinal: int,
    ctx: &Arena
) runtime.MirRuntimeComponentIdentity[ctx] {
    mut component: runtime.MirRuntimeComponentIdentity[ctx];
    component.component_id = runtime.mir_runtime_component_identity_id(kind, target_id, ordinal, ctx);
    component.component_kind = kind;
    component.source_path = source_path;
    component.object_identity = object_identity;
    component.target_id = target_id;
    return component;
}

func package_make_symbol(
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

func package_make_package(
    target_id: str,
    version: str,
    form: str,
    runtime_abi_id: str,
    ordinal: int,
    ctx: &Arena
) runtime.MirRuntimePackageIdentity[ctx] {
    mut package: runtime.MirRuntimePackageIdentity[ctx];
    package.package_id = runtime.mir_runtime_package_identity_id(target_id, version, ordinal, ctx);
    package.package_version = version;
    package.target_id = target_id;
    package.available = 1;
    package.manifest_format = "gust.runtime_package_manifest.v1";
    package.package_form = form;
    package.runtime_abi_id = runtime_abi_id;
    package.target_triple = "x86_64-unknown-linux-gnu";
    package.build_authority_id = "runtime_build_authority:gust_runtime_package";
    package.compatible_version_min = 1;
    package.compatible_version_max = 1;
    return package;
}

func package_make_member(
    package_id: str,
    component: runtime.MirRuntimeComponentIdentity[ctx],
    link_order: int,
    ctx: &Arena
) runtime.MirRuntimePackageMember[ctx] {
    mut member: runtime.MirRuntimePackageMember[ctx];
    member.member_id = runtime.mir_runtime_package_member_id(package_id, component.component_id, link_order, ctx);
    member.package_id = package_id;
    member.component_id = component.component_id;
    member.link_order = link_order;
    member.object_identity = component.object_identity;
    return member;
}

func package_make_provided(
    package_id: str,
    symbol: runtime.MirRuntimeSymbolIdentity[ctx],
    ordinal: int,
    ctx: &Arena
) runtime.MirRuntimePackageProvidedSymbol[ctx] {
    mut provided: runtime.MirRuntimePackageProvidedSymbol[ctx];
    provided.provided_id = runtime.mir_runtime_package_provided_symbol_id(package_id, symbol.symbol_id, ordinal, ctx);
    provided.package_id = package_id;
    provided.symbol_id = symbol.symbol_id;
    provided.external_spelling = symbol.external_spelling;
    provided.symbol_version = symbol.symbol_version;
    provided.component_id = symbol.component_id;
    return provided;
}

func package_requirement_vector(
    requirement: runtime.MirRuntimeRequirement[ctx],
    ctx: &Arena
) Index[std.Vector[runtime.MirRuntimeRequirement[ctx], ctx], ctx] {
    mut result := runtime.mir_runtime_empty_requirements(ctx);
    mut values: std.Vector[runtime.MirRuntimeRequirement[ctx], ctx] := ctx[result];
    values.Push(requirement);
    ctx.Set(result, values);
    return result;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_id := package_target_id();
    mut applicability := "all_declared_host_targets_from_phase14_target_authority";
    mut program_id := "program:phase17_4_runtime_package_smoke";
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

    // Two declared components give the manifest a real link order to be
    // deterministic about rather than a single trivial member.
    mut imports_component := package_make_component("stable_runtime_library_function", "src/runtime/approved_scalar_imports.c", "runtime:approved_scalar_imports", target_id, 0, &ctx);
    table = runtime.mir_runtime_table_with_component(table, imports_component, &ctx);
    mut arena_component := package_make_component("retained_c_runtime_component", "src/runtime/arena.c", "runtime:arena", target_id, 1, &ctx);
    table = runtime.mir_runtime_table_with_component(table, arena_component, &ctx);

    mut helper: runtime.MirRuntimeHelperIdentity[ctx];
    helper.helper_id = runtime.mir_runtime_helper_identity_id("tiny_host_add_one_i32", target_id, 0, &ctx);
    helper.operation_id = "tiny_host_add_one_i32";
    helper.symbol_identity = "tiny_host_add_one_i32";
    helper.source_location = "src/runtime/approved_scalar_imports.c:5";
    helper.target_applicability = applicability;
    table = runtime.mir_runtime_table_with_helper(table, helper, &ctx);

    mut classification: runtime.MirRuntimeHelperClassification[ctx];
    classification.classification_id = runtime.mir_runtime_classification_id(helper.helper_id, 0, &ctx);
    classification.helper_id = helper.helper_id;
    classification.classification = "stable_runtime_library_function";
    classification.component_id = imports_component.component_id;
    classification.reason_code = "runtime_helper_classified_stable_library_import";
    table = runtime.mir_runtime_table_with_classification(table, classification, &ctx);

    mut symbol := package_make_symbol(helper.helper_id, "tiny_host_add_one_i32", "i32_to_i32", imports_component.component_id, abi.runtime_abi_id, target_id, 0, &ctx);
    table = runtime.mir_runtime_table_with_symbol(table, symbol, &ctx);

    mut package := package_make_package(target_id, "gust-runtime-package-v1", "static_archive", abi.runtime_abi_id, 0, &ctx);
    table = runtime.mir_runtime_table_with_package(table, package, &ctx);
    mut member_zero := package_make_member(package.package_id, imports_component, 0, &ctx);
    table = runtime.mir_runtime_table_with_package_member(table, member_zero, &ctx);
    mut member_one := package_make_member(package.package_id, arena_component, 1, &ctx);
    table = runtime.mir_runtime_table_with_package_member(table, member_one, &ctx);
    table = runtime.mir_runtime_table_with_package_provided_symbol(table, package_make_provided(package.package_id, symbol, 0, &ctx), &ctx);

    mut system_import: runtime.MirRuntimePackageSystemImport[ctx];
    system_import.import_id = runtime.mir_runtime_package_system_import_id(package.package_id, "memcpy", 0, &ctx);
    system_import.package_id = package.package_id;
    system_import.external_spelling = "memcpy";
    system_import.origin = "permitted_c_runtime_system_import";
    table = runtime.mir_runtime_table_with_package_system_import(table, system_import, &ctx);

    mut requirement: runtime.MirRuntimeRequirement[ctx];
    requirement.requirement_id = runtime.mir_runtime_requirement_id(program_id, helper.helper_id, 0, &ctx);
    requirement.program_id = program_id;
    requirement.mir_operation_id = "mir_op:call:add_one:0";
    requirement.helper_id = helper.helper_id;
    requirement.runtime_abi_id = abi.runtime_abi_id;
    requirement.component_id = imports_component.component_id;
    requirement.package_id = package.package_id;
    requirement.required = 1;
    requirement.symbol_id = symbol.symbol_id;
    requirement.required_version_min = 1;
    requirement.required_version_max = 1;
    requirement.target_id = target_id;
    requirement.layout_id = symbol.layout_id;
    requirement.resource_operation_id = symbol.resource_operation_id;
    requirement.function_abi_id = symbol.function_abi_id;
    requirement.call_kind = "direct_call";
    requirement.package_mandatory = 1;
    table = runtime.mir_runtime_table_with_requirement(table, requirement, &ctx);

    // Phase 9G executes this plan; the component order in it is the package's.
    mut plan: runtime.MirRuntimeLinkPlanHandoff[ctx];
    plan.link_plan_id = runtime.mir_runtime_link_plan_id(program_id, package.package_id, target_id, 0, &ctx);
    plan.program_id = program_id;
    plan.package_id = package.package_id;
    plan.target_id = target_id;
    mut plan_components := runtime.mir_runtime_empty_strings(&ctx);
    mut plan_component_values: std.Vector[str, ctx] := ctx[plan_components];
    plan_component_values.Push(imports_component.component_id);
    plan_component_values.Push(arena_component.component_id);
    ctx.Set(plan_components, plan_component_values);
    plan.component_ids = plan_components;
    plan.symbol_identities = runtime.mir_runtime_empty_strings(&ctx);
    plan.compatible = 1;
    plan.reason_code = "runtime_link_plan_resolved";
    table = runtime.mir_runtime_table_with_link_plan(table, plan, &ctx);

    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, &ctx);
    if validation.valid == 0 { os.Exit(1); }

    // The manifest enumerates exactly what it declares.
    mut manifest := runtime.mir_runtime_package_manifest(table, package.package_id, &ctx);
    if manifest.valid == 0 { os.Exit(2); }
    if manifest.member_count != 2 || manifest.provided_symbol_count != 1 || manifest.system_import_count != 1 { os.Exit(3); }

    // Selection is a compiler-owned compatibility decision.
    mut requirements := package_requirement_vector(requirement, &ctx);
    mut selection := runtime.mir_runtime_select_package_for_target(table, requirements, target_id, &ctx);
    if selection.found == 0 || std.str_eq(selection.value.package_id, package.package_id) == 0 { os.Exit(4); }
    if std.str_eq(selection.reason_code, "runtime_package_selected") == 0 { os.Exit(5); }
    if std.str_eq(selection.value.package_form, "static_archive") == 0 { os.Exit(6); }

    // A target with no package is a rejection, not a fallback.
    mut absent := runtime.mir_runtime_select_package_for_target(table, requirements, "target:v1:triple=aarch64-unknown-linux-gnu", &ctx);
    if absent.found == 1 { os.Exit(7); }

    mut serialized := runtime.mir_serialize_runtime_boundary_authority_table_for_request(table, &ctx);
    if std.str_find(serialized, "runtime_package_form: static_archive") == 0 - 1 { os.Exit(8); }
    if std.str_find(serialized, "runtime_package_member_link_order: 1") == 0 - 1 { os.Exit(9); }
    if std.str_find(serialized, "runtime_package_system_import_spelling: memcpy") == 0 - 1 { os.Exit(10); }

    // Rejection: two available packages both satisfy the same requirement.
    mut ambiguous_package := package_make_package(target_id, "gust-runtime-package-v2", "deterministic_object_set", abi.runtime_abi_id, 1, &ctx);
    mut ambiguous_table := runtime.mir_runtime_table_with_package(table, ambiguous_package, &ctx);
    ambiguous_table = runtime.mir_runtime_table_with_package_member(ambiguous_table, package_make_member(ambiguous_package.package_id, imports_component, 0, &ctx), &ctx);
    ambiguous_table = runtime.mir_runtime_table_with_package_provided_symbol(ambiguous_table, package_make_provided(ambiguous_package.package_id, symbol, 1, &ctx), &ctx);
    mut ambiguous_selection := runtime.mir_runtime_select_package_for_target(ambiguous_table, requirements, target_id, &ctx);
    if ambiguous_selection.found == 1 || std.str_eq(ambiguous_selection.reason_code, "runtime_package_ambiguous_selection") == 0 { os.Exit(11); }

    // Rejection: a package declared for a different target.
    mut wrong_target_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    wrong_target_table = runtime.mir_runtime_table_with_abi(wrong_target_table, abi, &ctx);
    wrong_target_table = runtime.mir_runtime_table_with_component(wrong_target_table, imports_component, &ctx);
    mut wrong_target_package := package_make_package(target_id, "gust-runtime-package-v1", "static_archive", abi.runtime_abi_id, 0, &ctx);
    wrong_target_package.target_triple = "aarch64-unknown-linux-gnu";
    wrong_target_table = runtime.mir_runtime_table_with_package(wrong_target_table, wrong_target_package, &ctx);
    wrong_target_table = runtime.mir_runtime_table_with_package_member(wrong_target_table, package_make_member(wrong_target_package.package_id, imports_component, 0, &ctx), &ctx);
    mut wrong_target_validation := runtime.mir_runtime_boundary_authority_table_validate(wrong_target_table, &ctx);
    if wrong_target_validation.valid == 1 || std.str_eq(wrong_target_validation.reason_code, "runtime_package_target_mismatch") == 0 { os.Exit(12); }

    // Rejection: the same component enumerated twice in one package.
    mut duplicate_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    duplicate_table = runtime.mir_runtime_table_with_abi(duplicate_table, abi, &ctx);
    duplicate_table = runtime.mir_runtime_table_with_component(duplicate_table, imports_component, &ctx);
    duplicate_table = runtime.mir_runtime_table_with_package(duplicate_table, package, &ctx);
    duplicate_table = runtime.mir_runtime_table_with_package_member(duplicate_table, package_make_member(package.package_id, imports_component, 0, &ctx), &ctx);
    duplicate_table = runtime.mir_runtime_table_with_package_member(duplicate_table, package_make_member(package.package_id, imports_component, 1, &ctx), &ctx);
    mut duplicate_validation := runtime.mir_runtime_boundary_authority_table_validate(duplicate_table, &ctx);
    if duplicate_validation.valid == 1 || std.str_eq(duplicate_validation.reason_code, "runtime_package_duplicate_conflicting_component") == 0 { os.Exit(13); }

    // Rejection: a mandatory requirement the selected package does not provide.
    mut missing_symbol_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    missing_symbol_table = runtime.mir_runtime_table_with_abi(missing_symbol_table, abi, &ctx);
    missing_symbol_table = runtime.mir_runtime_table_with_component(missing_symbol_table, imports_component, &ctx);
    missing_symbol_table = runtime.mir_runtime_table_with_helper(missing_symbol_table, helper, &ctx);
    missing_symbol_table = runtime.mir_runtime_table_with_classification(missing_symbol_table, classification, &ctx);
    missing_symbol_table = runtime.mir_runtime_table_with_symbol(missing_symbol_table, symbol, &ctx);
    missing_symbol_table = runtime.mir_runtime_table_with_package(missing_symbol_table, package, &ctx);
    missing_symbol_table = runtime.mir_runtime_table_with_package_member(missing_symbol_table, member_zero, &ctx);
    missing_symbol_table = runtime.mir_runtime_table_with_requirement(missing_symbol_table, requirement, &ctx);
    mut missing_symbol_validation := runtime.mir_runtime_boundary_authority_table_validate(missing_symbol_table, &ctx);
    if missing_symbol_validation.valid == 1 || std.str_eq(missing_symbol_validation.reason_code, "runtime_package_missing_mandatory_symbol") == 0 { os.Exit(14); }

    // Rejection: a package claiming a range outside the frozen runtime ABI.
    mut version_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    version_table = runtime.mir_runtime_table_with_abi(version_table, abi, &ctx);
    version_table = runtime.mir_runtime_table_with_component(version_table, imports_component, &ctx);
    mut version_package := package_make_package(target_id, "gust-runtime-package-v1", "static_archive", abi.runtime_abi_id, 0, &ctx);
    version_package.compatible_version_max = 3;
    version_table = runtime.mir_runtime_table_with_package(version_table, version_package, &ctx);
    version_table = runtime.mir_runtime_table_with_package_member(version_table, package_make_member(version_package.package_id, imports_component, 0, &ctx), &ctx);
    mut version_validation := runtime.mir_runtime_boundary_authority_table_validate(version_table, &ctx);
    if version_validation.valid == 1 || std.str_eq(version_validation.reason_code, "runtime_package_abi_version_incompatible") == 0 { os.Exit(15); }

    // Rejection: an archive member whose component was never declared.
    mut undeclared_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    undeclared_table = runtime.mir_runtime_table_with_abi(undeclared_table, abi, &ctx);
    undeclared_table = runtime.mir_runtime_table_with_component(undeclared_table, imports_component, &ctx);
    undeclared_table = runtime.mir_runtime_table_with_package(undeclared_table, package, &ctx);
    undeclared_table = runtime.mir_runtime_table_with_package_member(undeclared_table, package_make_member(package.package_id, arena_component, 0, &ctx), &ctx);
    mut undeclared_validation := runtime.mir_runtime_boundary_authority_table_validate(undeclared_table, &ctx);
    if undeclared_validation.valid == 1 || std.str_eq(undeclared_validation.reason_code, "runtime_package_undeclared_member_or_system_import") == 0 { os.Exit(16); }

    // Rejection: members that do not occupy a dense ascending link order.
    mut order_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    order_table = runtime.mir_runtime_table_with_abi(order_table, abi, &ctx);
    order_table = runtime.mir_runtime_table_with_component(order_table, imports_component, &ctx);
    order_table = runtime.mir_runtime_table_with_component(order_table, arena_component, &ctx);
    order_table = runtime.mir_runtime_table_with_package(order_table, package, &ctx);
    order_table = runtime.mir_runtime_table_with_package_member(order_table, package_make_member(package.package_id, imports_component, 0, &ctx), &ctx);
    order_table = runtime.mir_runtime_table_with_package_member(order_table, package_make_member(package.package_id, arena_component, 2, &ctx), &ctx);
    mut order_validation := runtime.mir_runtime_boundary_authority_table_validate(order_table, &ctx);
    if order_validation.valid == 1 || std.str_eq(order_validation.reason_code, "runtime_package_nondeterministic_component_order") == 0 { os.Exit(17); }

    // Rejection: a Phase 9G link plan that reorders the declared components.
    mut plan_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    plan_table = runtime.mir_runtime_table_with_abi(plan_table, abi, &ctx);
    plan_table = runtime.mir_runtime_table_with_component(plan_table, imports_component, &ctx);
    plan_table = runtime.mir_runtime_table_with_component(plan_table, arena_component, &ctx);
    plan_table = runtime.mir_runtime_table_with_package(plan_table, package, &ctx);
    plan_table = runtime.mir_runtime_table_with_package_member(plan_table, member_zero, &ctx);
    plan_table = runtime.mir_runtime_table_with_package_member(plan_table, member_one, &ctx);
    mut reordered: runtime.MirRuntimeLinkPlanHandoff[ctx];
    reordered.link_plan_id = runtime.mir_runtime_link_plan_id(program_id, package.package_id, target_id, 1, &ctx);
    reordered.program_id = program_id;
    reordered.package_id = package.package_id;
    reordered.target_id = target_id;
    mut reordered_components := runtime.mir_runtime_empty_strings(&ctx);
    mut reordered_values: std.Vector[str, ctx] := ctx[reordered_components];
    reordered_values.Push(arena_component.component_id);
    reordered_values.Push(imports_component.component_id);
    ctx.Set(reordered_components, reordered_values);
    reordered.component_ids = reordered_components;
    reordered.symbol_identities = runtime.mir_runtime_empty_strings(&ctx);
    reordered.compatible = 1;
    reordered.reason_code = "runtime_link_plan_resolved";
    plan_table = runtime.mir_runtime_table_with_link_plan(plan_table, reordered, &ctx);
    mut plan_validation := runtime.mir_runtime_boundary_authority_table_validate(plan_table, &ctx);
    if plan_validation.valid == 1 || std.str_eq(plan_validation.reason_code, "runtime_package_nondeterministic_component_order") == 0 { os.Exit(18); }

    // Keep the request module in the generic producer graph without requiring a
    // native driver, worker, object, linker, or output artifact in Level 1.
    if std.str_eq("runtime_request", "runtime_request") == 0 { os.Exit(19); }
    os.LogStr("SUCCESS: Phase 17.4 runtime package smoke passed");
}
