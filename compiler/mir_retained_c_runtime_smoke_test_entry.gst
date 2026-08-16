// Phase 17.7 native smoke: retained C runtime objects as explicit, separately
// compiled, versioned, target-scoped components.
//
// Proves a retained C component carries owned repository sources, versioned
// exports reachable only through the selected package manifest, a justified
// retention reason and a stated removal criterion. Asserts the validator rejects
// anonymous objects, program-specific C generation, unversioned exports, hidden
// target assumptions, duplicate providers, and direct linker inclusion.

import "mir_runtime_boundary_authority.gst" as runtime;
import "mir_retained_c_runtime_request.gst" as retained_request;

func retained_target_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func retained_applicability() str {
    return "all_declared_host_targets_from_phase14_target_authority";
}

func retained_strings(first: str, second: str, ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut result := runtime.mir_runtime_empty_strings(ctx);
    mut values: std.Vector[str, ctx] := ctx[result];
    if len(first) != 0 { values.Push(first); }
    if len(second) != 0 { values.Push(second); }
    ctx.Set(result, values);
    return result;
}

func retained_table(
    abi: runtime.MirRuntimeAbiIdentity[ctx],
    component: runtime.MirRuntimeComponentIdentity[ctx],
    package: runtime.MirRuntimePackageIdentity[ctx],
    member: runtime.MirRuntimePackageMember[ctx],
    provided: runtime.MirRuntimePackageProvidedSymbol[ctx],
    helper: runtime.MirRuntimeHelperIdentity[ctx],
    classification: runtime.MirRuntimeHelperClassification[ctx],
    symbol: runtime.MirRuntimeSymbolIdentity[ctx],
    retained: runtime.MirRuntimeRetainedCComponent[ctx],
    include_provided: int,
    ctx: &Arena
) runtime.MirRuntimeBoundaryAuthorityTable[ctx] {
    mut result := runtime.mir_runtime_make_empty_table(retained_target_id(), "x86_64-unknown-linux-gnu", ctx);
    result = runtime.mir_runtime_table_with_abi(result, abi, ctx);
    result = runtime.mir_runtime_table_with_component(result, component, ctx);
    result = runtime.mir_runtime_table_with_package(result, package, ctx);
    result = runtime.mir_runtime_table_with_package_member(result, member, ctx);
    if include_provided == 1 { result = runtime.mir_runtime_table_with_package_provided_symbol(result, provided, ctx); }
    result = runtime.mir_runtime_table_with_helper(result, helper, ctx);
    result = runtime.mir_runtime_table_with_classification(result, classification, ctx);
    result = runtime.mir_runtime_table_with_symbol(result, symbol, ctx);
    return runtime.mir_runtime_table_with_retained_c_component(result, retained, ctx);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_id := retained_target_id();

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

    mut component: runtime.MirRuntimeComponentIdentity[ctx];
    component.component_id = runtime.mir_runtime_component_identity_id("retained_c_runtime_component", target_id, 0, &ctx);
    component.component_kind = "retained_c_runtime_component";
    component.source_path = "src/runtime/arena.c";
    component.object_identity = "runtime:arena";
    component.target_id = target_id;

    mut helper: runtime.MirRuntimeHelperIdentity[ctx];
    helper.helper_id = runtime.mir_runtime_helper_identity_id("os_Arena_New", target_id, 0, &ctx);
    helper.operation_id = "os_Arena_New";
    helper.symbol_identity = "os_Arena_New";
    helper.source_location = "src/runtime/arena.c:28";
    helper.target_applicability = retained_applicability();

    mut classification: runtime.MirRuntimeHelperClassification[ctx];
    classification.classification_id = runtime.mir_runtime_classification_id(helper.helper_id, 0, &ctx);
    classification.helper_id = helper.helper_id;
    classification.classification = "retained_c_runtime_component";
    classification.component_id = component.component_id;
    classification.reason_code = "runtime_helper_classified_retained_c_component";

    mut symbol: runtime.MirRuntimeSymbolIdentity[ctx];
    symbol.symbol_id = runtime.mir_runtime_symbol_identity_id(helper.helper_id, "gust-runtime-symbol-v1", target_id, 0, &ctx);
    symbol.helper_id = helper.helper_id;
    symbol.external_spelling = "os_Arena_New";
    symbol.symbol_version = "gust-runtime-symbol-v1";
    symbol.component_id = component.component_id;
    symbol.runtime_abi_id = abi.runtime_abi_id;
    symbol.function_abi_id = "function_abi:runtime:os_Arena_New:i32_to_i32:gust_canonical_v1";
    symbol.calling_convention_id = "gust_canonical_v1";
    symbol.layout_id = "layout:type:gust:i32";
    symbol.resource_operation_id = "none_scalar_runtime_operation";
    symbol.target_id = target_id;
    symbol.target_triple = "x86_64-unknown-linux-gnu";
    symbol.required = 1;
    symbol.visibility = "public_runtime_import";
    symbol.linkage = "external_static_runtime_package";
    symbol.compatibility_policy = "exact_major_compatible_minor_range_1_1";

    mut package: runtime.MirRuntimePackageIdentity[ctx];
    package.package_id = runtime.mir_runtime_package_identity_id(target_id, "gust-runtime-package-v1", 0, &ctx);
    package.package_version = "gust-runtime-package-v1";
    package.target_id = target_id;
    package.available = 1;
    package.manifest_format = "gust.runtime_package_manifest.v1";
    package.package_form = "static_archive";
    package.runtime_abi_id = abi.runtime_abi_id;
    package.target_triple = "x86_64-unknown-linux-gnu";
    package.build_authority_id = "runtime_build_authority:gust_runtime_package";
    package.compatible_version_min = 1;
    package.compatible_version_max = 1;

    mut member: runtime.MirRuntimePackageMember[ctx];
    member.member_id = runtime.mir_runtime_package_member_id(package.package_id, component.component_id, 0, &ctx);
    member.package_id = package.package_id;
    member.component_id = component.component_id;
    member.link_order = 0;
    member.object_identity = component.object_identity;

    mut provided: runtime.MirRuntimePackageProvidedSymbol[ctx];
    provided.provided_id = runtime.mir_runtime_package_provided_symbol_id(package.package_id, symbol.symbol_id, 0, &ctx);
    provided.package_id = package.package_id;
    provided.symbol_id = symbol.symbol_id;
    provided.external_spelling = symbol.external_spelling;
    provided.symbol_version = symbol.symbol_version;
    provided.component_id = symbol.component_id;

    mut retained: runtime.MirRuntimeRetainedCComponent[ctx];
    retained.retained_component_id = runtime.mir_runtime_retained_c_component_id(component.component_id, abi.runtime_abi_id, target_id, 0, &ctx);
    retained.component_id = component.component_id;
    retained.owned_source_paths = retained_strings("src/runtime/arena.c", "src/runtime/core_headers.h", &ctx);
    retained.exported_symbol_ids = retained_strings(symbol.symbol_id, "", &ctx);
    retained.imported_symbol_ids = retained_strings("", "", &ctx);
    retained.runtime_abi_id = abi.runtime_abi_id;
    retained.target_id = target_id;
    retained.target_applicability = retained_applicability();
    retained.build_inputs = "cc_c99_src_runtime_arena_c_independent_of_program_compilation";
    retained.retention_reason = "awaiting_pure_gust_migration";
    retained.removal_criterion = "removed_when_arena_operations_compile_through_mir_in_patch17_8";
    retained.destination_phase = "17.8";

    mut table := retained_table(abi, component, package, member, provided, helper, classification, symbol, retained, 1, &ctx);
    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    mut query := runtime.mir_runtime_retained_c_for(table, component.component_id, &ctx);
    if query.found == 0 { os.Exit(2); }
    if std.str_eq(query.value.retention_reason, "awaiting_pure_gust_migration") == 0 { os.Exit(3); }
    if std.str_eq(query.value.destination_phase, "17.8") == 0 { os.Exit(4); }
    mut absent := runtime.mir_runtime_retained_c_for(table, "runtime_component:not_retained", &ctx);
    if absent.found == 1 { os.Exit(5); }

    mut serialized := runtime.mir_serialize_runtime_boundary_authority_table_for_request(table, &ctx);
    if std.str_find(serialized, "runtime_retained_c_retention_reason: awaiting_pure_gust_migration") == 0 - 1 { os.Exit(6); }
    if std.str_find(serialized, "runtime_retained_c_destination_phase: 17.8") == 0 - 1 { os.Exit(7); }

    // Rejection: retention with no justified reason is an unclassified object.
    mut anonymous := retained;
    anonymous.retention_reason = "because_it_works";
    mut anonymous_validation := runtime.mir_runtime_boundary_authority_table_validate(
        retained_table(abi, component, package, member, provided, helper, classification, symbol, anonymous, 1, &ctx), &ctx);
    if anonymous_validation.valid == 1 || std.str_eq(anonymous_validation.reason_code, "runtime_retained_c_anonymous_object") == 0 { os.Exit(8); }

    // Rejection: source generated from a compiled program rather than owned.
    mut generated := retained;
    generated.owned_source_paths = retained_strings("build/generated/program_shim.c", "", &ctx);
    mut generated_validation := runtime.mir_runtime_boundary_authority_table_validate(
        retained_table(abi, component, package, member, provided, helper, classification, symbol, generated, 1, &ctx), &ctx);
    if generated_validation.valid == 1 || std.str_eq(generated_validation.reason_code, "runtime_retained_c_program_specific_generation") == 0 { os.Exit(9); }

    // Rejection: an export the compiler does not own a versioned symbol for.
    mut unversioned := retained;
    unversioned.exported_symbol_ids = retained_strings("runtime_symbol:v1:helper=not_compiler_owned", "", &ctx);
    mut unversioned_validation := runtime.mir_runtime_boundary_authority_table_validate(
        retained_table(abi, component, package, member, provided, helper, classification, symbol, unversioned, 1, &ctx), &ctx);
    if unversioned_validation.valid == 1 || std.str_eq(unversioned_validation.reason_code, "runtime_retained_c_unversioned_export") == 0 { os.Exit(10); }

    // Rejection: a target assumption that is not the declared one.
    mut hidden := retained;
    hidden.target_applicability = "assumes_posix";
    mut hidden_validation := runtime.mir_runtime_boundary_authority_table_validate(
        retained_table(abi, component, package, member, provided, helper, classification, symbol, hidden, 1, &ctx), &ctx);
    if hidden_validation.valid == 1 || std.str_eq(hidden_validation.reason_code, "runtime_retained_c_hidden_target_assumption") == 0 { os.Exit(11); }

    // Rejection: the component reaching the linker outside the package manifest.
    mut unpackaged_validation := runtime.mir_runtime_boundary_authority_table_validate(
        retained_table(abi, component, package, member, provided, helper, classification, symbol, retained, 0, &ctx), &ctx);
    if unpackaged_validation.valid == 1 || std.str_eq(unpackaged_validation.reason_code, "runtime_retained_c_direct_linker_inclusion") == 0 { os.Exit(12); }

    // Rejection: two retained components providing the same export.
    mut second := retained;
    second.retained_component_id = runtime.mir_runtime_retained_c_component_id(component.component_id, abi.runtime_abi_id, target_id, 1, &ctx);
    mut duplicate_table := runtime.mir_runtime_table_with_retained_c_component(
        retained_table(abi, component, package, member, provided, helper, classification, symbol, retained, 1, &ctx), second, &ctx);
    mut duplicate_validation := runtime.mir_runtime_boundary_authority_table_validate(duplicate_table, &ctx);
    if duplicate_validation.valid == 1 || std.str_eq(duplicate_validation.reason_code, "runtime_retained_c_duplicate_provider") == 0 { os.Exit(13); }

    mut request := retained_request.mir_serialize_retained_c_request(table, &ctx);
    mut witness := retained_request.mir_retained_c_mir_to_c_witness(table, &ctx);
    if os.WriteFile("/tmp/gust-phase17-retained-c.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase17-retained-c.mir-to-c.witness", witness) == 0
    {
        os.Exit(14);
    }
    if std.str_find(witness, "linkage=separately_compiled_component_no_program_derived_c_source") == 0 - 1 { os.Exit(15); }

    os.LogStr("SUCCESS: Phase 17.7 retained C runtime smoke passed");
}
