// Phase 17.5 native smoke: stable runtime-library imports for Cranelift.
//
// Builds the three approved scalar imports as compiler-owned versioned import
// declarations, writes the request and the MIR-to-C witness for the parity
// guard, and asserts the validator rejects missing symbols, incompatible
// versions, ABI mismatch, wrong target components, and undeclared imports.

import "mir_runtime_boundary_authority.gst" as runtime;
import "mir_runtime_import_request.gst" as import_request;

func import_target_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func import_applicability() str {
    return "all_declared_host_targets_from_phase14_target_authority";
}

func import_make_symbol(
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

func import_make_declaration(
    symbol: runtime.MirRuntimeSymbolIdentity[ctx],
    package_id: str,
    ordinal: int,
    ctx: &Arena
) runtime.MirRuntimeImportDeclaration[ctx] {
    mut declaration: runtime.MirRuntimeImportDeclaration[ctx];
    declaration.import_id = runtime.mir_runtime_import_declaration_id(symbol.helper_id, symbol.symbol_version, symbol.target_id, ordinal, ctx);
    declaration.helper_id = symbol.helper_id;
    declaration.symbol_id = symbol.symbol_id;
    declaration.external_spelling = symbol.external_spelling;
    declaration.symbol_version = symbol.symbol_version;
    declaration.function_abi_id = symbol.function_abi_id;
    declaration.component_id = symbol.component_id;
    declaration.package_id = package_id;
    declaration.target_id = symbol.target_id;
    declaration.target_applicability = import_applicability();
    declaration.side_effect_policy = "pure_scalar_no_side_effects";
    declaration.failure_policy = "total_cannot_fail";
    return declaration;
}

func import_make_provided(
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

// A fresh minimal table carrying exactly one import declaration, so a negative
// assertion reports the defect under test rather than a duplicate-row conflict.
func import_negative_table(
    abi: runtime.MirRuntimeAbiIdentity[ctx],
    component: runtime.MirRuntimeComponentIdentity[ctx],
    package: runtime.MirRuntimePackageIdentity[ctx],
    member: runtime.MirRuntimePackageMember[ctx],
    helper: runtime.MirRuntimeHelperIdentity[ctx],
    classification: runtime.MirRuntimeHelperClassification[ctx],
    symbol: runtime.MirRuntimeSymbolIdentity[ctx],
    declaration: runtime.MirRuntimeImportDeclaration[ctx],
    ctx: &Arena
) runtime.MirRuntimeBoundaryAuthorityTable[ctx] {
    mut result := runtime.mir_runtime_make_empty_table(import_target_id(), "x86_64-unknown-linux-gnu", ctx);
    result = runtime.mir_runtime_table_with_abi(result, abi, ctx);
    result = runtime.mir_runtime_table_with_component(result, component, ctx);
    result = runtime.mir_runtime_table_with_package(result, package, ctx);
    result = runtime.mir_runtime_table_with_package_member(result, member, ctx);
    result = runtime.mir_runtime_table_with_helper(result, helper, ctx);
    result = runtime.mir_runtime_table_with_classification(result, classification, ctx);
    result = runtime.mir_runtime_table_with_symbol(result, symbol, ctx);
    result = runtime.mir_runtime_table_with_package_provided_symbol(result, import_make_provided(package.package_id, symbol, 0, ctx), ctx);
    return runtime.mir_runtime_table_with_import_declaration(result, declaration, ctx);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_id := import_target_id();
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
    package.manifest_format = "gust.runtime_package_manifest.v1";
    package.package_form = "static_archive";
    package.runtime_abi_id = abi.runtime_abi_id;
    package.target_triple = "x86_64-unknown-linux-gnu";
    package.build_authority_id = "runtime_build_authority:gust_runtime_package";
    package.compatible_version_min = 1;
    package.compatible_version_max = 1;
    table = runtime.mir_runtime_table_with_package(table, package, &ctx);

    mut member: runtime.MirRuntimePackageMember[ctx];
    member.member_id = runtime.mir_runtime_package_member_id(package.package_id, component.component_id, 0, &ctx);
    member.package_id = package.package_id;
    member.component_id = component.component_id;
    member.link_order = 0;
    member.object_identity = component.object_identity;
    table = runtime.mir_runtime_table_with_package_member(table, member, &ctx);

    // Three approved scalar imports, declared in compiler-owned order.
    mut helper_one: runtime.MirRuntimeHelperIdentity[ctx];
    helper_one.helper_id = runtime.mir_runtime_helper_identity_id("tiny_host_add_one_i32", target_id, 0, &ctx);
    helper_one.operation_id = "tiny_host_add_one_i32";
    helper_one.symbol_identity = "tiny_host_add_one_i32";
    helper_one.source_location = "src/runtime/approved_scalar_imports.c:5";
    helper_one.target_applicability = import_applicability();
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
    helper_two.target_applicability = import_applicability();
    table = runtime.mir_runtime_table_with_helper(table, helper_two, &ctx);

    mut classification_two: runtime.MirRuntimeHelperClassification[ctx];
    classification_two.classification_id = runtime.mir_runtime_classification_id(helper_two.helper_id, 1, &ctx);
    classification_two.helper_id = helper_two.helper_id;
    classification_two.classification = "stable_runtime_library_function";
    classification_two.component_id = component.component_id;
    classification_two.reason_code = "runtime_helper_classified_stable_library_import";
    table = runtime.mir_runtime_table_with_classification(table, classification_two, &ctx);

    mut helper_three: runtime.MirRuntimeHelperIdentity[ctx];
    helper_three.helper_id = runtime.mir_runtime_helper_identity_id("tiny_host_is_positive_i32", target_id, 2, &ctx);
    helper_three.operation_id = "tiny_host_is_positive_i32";
    helper_three.symbol_identity = "tiny_host_is_positive_i32";
    helper_three.source_location = "src/runtime/approved_scalar_imports.c:13";
    helper_three.target_applicability = import_applicability();
    table = runtime.mir_runtime_table_with_helper(table, helper_three, &ctx);

    mut classification_three: runtime.MirRuntimeHelperClassification[ctx];
    classification_three.classification_id = runtime.mir_runtime_classification_id(helper_three.helper_id, 2, &ctx);
    classification_three.helper_id = helper_three.helper_id;
    classification_three.classification = "stable_runtime_library_function";
    classification_three.component_id = component.component_id;
    classification_three.reason_code = "runtime_helper_classified_stable_library_import";
    table = runtime.mir_runtime_table_with_classification(table, classification_three, &ctx);

    mut symbol_one := import_make_symbol(helper_one.helper_id, "tiny_host_add_one_i32", "i32_to_i32", component.component_id, abi.runtime_abi_id, target_id, 0, &ctx);
    table = runtime.mir_runtime_table_with_symbol(table, symbol_one, &ctx);
    mut symbol_two := import_make_symbol(helper_two.helper_id, "tiny_host_add_i32", "i32_i32_to_i32", component.component_id, abi.runtime_abi_id, target_id, 1, &ctx);
    table = runtime.mir_runtime_table_with_symbol(table, symbol_two, &ctx);
    mut symbol_three := import_make_symbol(helper_three.helper_id, "tiny_host_is_positive_i32", "i32_to_i32", component.component_id, abi.runtime_abi_id, target_id, 2, &ctx);
    table = runtime.mir_runtime_table_with_symbol(table, symbol_three, &ctx);

    table = runtime.mir_runtime_table_with_package_provided_symbol(table, import_make_provided(package.package_id, symbol_one, 0, &ctx), &ctx);
    table = runtime.mir_runtime_table_with_package_provided_symbol(table, import_make_provided(package.package_id, symbol_two, 1, &ctx), &ctx);
    table = runtime.mir_runtime_table_with_package_provided_symbol(table, import_make_provided(package.package_id, symbol_three, 2, &ctx), &ctx);

    mut declaration_one := import_make_declaration(symbol_one, package.package_id, 0, &ctx);
    table = runtime.mir_runtime_table_with_import_declaration(table, declaration_one, &ctx);
    mut declaration_two := import_make_declaration(symbol_two, package.package_id, 1, &ctx);
    table = runtime.mir_runtime_table_with_import_declaration(table, declaration_two, &ctx);
    mut declaration_three := import_make_declaration(symbol_three, package.package_id, 2, &ctx);
    table = runtime.mir_runtime_table_with_import_declaration(table, declaration_three, &ctx);

    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    mut lookup := runtime.mir_runtime_import_for(table, helper_two.helper_id, target_id, &ctx);
    if lookup.found == 0 || std.str_eq(lookup.value.external_spelling, "tiny_host_add_i32") == 0 { os.Exit(2); }
    if std.str_eq(lookup.value.symbol_version, "gust-runtime-symbol-v1") == 0 { os.Exit(3); }
    mut absent := runtime.mir_runtime_import_for(table, "p17_helper_not_migrated", target_id, &ctx);
    if absent.found == 1 { os.Exit(4); }

    mut request := import_request.mir_serialize_runtime_import_request(table, &ctx);
    mut witness := import_request.mir_runtime_import_mir_to_c_witness(table, &ctx);
    if os.WriteFile("/tmp/gust-phase17-runtime-import.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase17-runtime-import.mir-to-c.witness", witness) == 0
    {
        os.Exit(5);
    }
    if std.str_find(witness, "linkage=direct_external_call_no_generated_c_glue") == 0 - 1 { os.Exit(6); }

    // Negatives build a fresh single-import table each time. Appending a bad row
    // to the table above would trip the duplicate-import check first and report
    // the wrong reason, which would make these assertions prove nothing.
    mut missing := import_make_declaration(symbol_one, package.package_id, 0, &ctx);
    missing.symbol_id = "runtime_symbol:v1:helper=not_compiler_owned";
    mut missing_validation := runtime.mir_runtime_boundary_authority_table_validate(
        import_negative_table(abi, component, package, member, helper_one, classification_one, symbol_one, missing, &ctx), &ctx);
    if missing_validation.valid == 1 || std.str_eq(missing_validation.reason_code, "runtime_import_missing_symbol") == 0 { os.Exit(7); }

    // Rejection: a version the compiler-owned symbol record does not carry.
    mut stale := import_make_declaration(symbol_one, package.package_id, 0, &ctx);
    stale.symbol_version = "gust-runtime-symbol-v2";
    mut stale_validation := runtime.mir_runtime_boundary_authority_table_validate(
        import_negative_table(abi, component, package, member, helper_one, classification_one, symbol_one, stale, &ctx), &ctx);
    if stale_validation.valid == 1 || std.str_eq(stale_validation.reason_code, "runtime_import_incompatible_version") == 0 { os.Exit(8); }

    // Rejection: a function ABI identity that disagrees with the symbol record.
    mut drifted := import_make_declaration(symbol_one, package.package_id, 0, &ctx);
    drifted.function_abi_id = "function_abi:runtime:tiny_host_add_one_i32:i64_to_i64:gust_canonical_v1";
    mut drifted_validation := runtime.mir_runtime_boundary_authority_table_validate(
        import_negative_table(abi, component, package, member, helper_one, classification_one, symbol_one, drifted, &ctx), &ctx);
    if drifted_validation.valid == 1 || std.str_eq(drifted_validation.reason_code, "runtime_import_abi_mismatch") == 0 { os.Exit(9); }

    // Rejection: an import claiming a component that is not the helper's.
    mut rehomed := import_make_declaration(symbol_one, package.package_id, 0, &ctx);
    rehomed.component_id = "runtime_component:arena";
    mut rehomed_validation := runtime.mir_runtime_boundary_authority_table_validate(
        import_negative_table(abi, component, package, member, helper_one, classification_one, symbol_one, rehomed, &ctx), &ctx);
    if rehomed_validation.valid == 1 || std.str_eq(rehomed_validation.reason_code, "runtime_import_wrong_target_component") == 0 { os.Exit(10); }

    // Rejection: an undeclared side-effect policy the backend could misread.
    mut undeclared := import_make_declaration(symbol_one, package.package_id, 0, &ctx);
    undeclared.side_effect_policy = "assume_pure";
    mut undeclared_validation := runtime.mir_runtime_boundary_authority_table_validate(
        import_negative_table(abi, component, package, member, helper_one, classification_one, symbol_one, undeclared, &ctx), &ctx);
    if undeclared_validation.valid == 1 || std.str_eq(undeclared_validation.reason_code, "runtime_import_undeclared") == 0 { os.Exit(11); }

    os.LogStr("SUCCESS: Phase 17.5 runtime import smoke passed");
}
