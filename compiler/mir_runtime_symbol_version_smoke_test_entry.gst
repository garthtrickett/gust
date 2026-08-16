import "mir_runtime_boundary_authority.gst" as runtime;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_id := "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
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

    mut helper: runtime.MirRuntimeHelperIdentity[ctx];
    helper.helper_id = runtime.mir_runtime_helper_identity_id("tiny_host_add_one_i32", target_id, 0, &ctx);
    helper.operation_id = "tiny_host_add_one_i32";
    helper.symbol_identity = "tiny_host_add_one_i32";
    helper.source_location = "src/runtime/approved_scalar_imports.c:5";
    helper.target_applicability = "all_declared_host_targets_from_phase14_target_authority";
    table = runtime.mir_runtime_table_with_helper(table, helper, &ctx);

    mut classification: runtime.MirRuntimeHelperClassification[ctx];
    classification.classification_id = runtime.mir_runtime_classification_id(helper.helper_id, 0, &ctx);
    classification.helper_id = helper.helper_id;
    classification.classification = "stable_runtime_library_function";
    classification.component_id = component.component_id;
    classification.reason_code = "runtime_helper_classified_stable_library_import";
    table = runtime.mir_runtime_table_with_classification(table, classification, &ctx);

    mut symbol: runtime.MirRuntimeSymbolIdentity[ctx];
    symbol.symbol_id = runtime.mir_runtime_symbol_identity_id(helper.helper_id, "gust-runtime-symbol-v1", target_id, 0, &ctx);
    symbol.helper_id = helper.helper_id;
    symbol.external_spelling = "tiny_host_add_one_i32";
    symbol.symbol_version = "gust-runtime-symbol-v1";
    symbol.component_id = component.component_id;
    symbol.runtime_abi_id = abi.runtime_abi_id;
    symbol.function_abi_id = "function_abi:runtime:tiny_host_add_one_i32:i32_to_i32:gust_canonical_v1";
    symbol.calling_convention_id = "gust_canonical_v1";
    symbol.layout_id = "layout:type:gust:i32";
    symbol.resource_operation_id = "none_scalar_runtime_operation";
    symbol.target_id = target_id;
    symbol.target_triple = "x86_64-unknown-linux-gnu";
    symbol.required = 1;
    symbol.visibility = "public_runtime_import";
    symbol.linkage = "external_static_runtime_package";
    symbol.compatibility_policy = "exact_major_compatible_minor_range_1_1";
    table = runtime.mir_runtime_table_with_symbol(table, symbol, &ctx);

    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, &ctx);
    if validation.valid == 0 { os.Exit(1); }
    mut abi_query := runtime.mir_runtime_abi_for(table, target_id, &ctx);
    if abi_query.found == 0 { os.Exit(2); }
    mut symbol_query := runtime.mir_runtime_symbol_for(table, helper.helper_id, target_id, &ctx);
    if symbol_query.found == 0 || std.str_eq(symbol_query.value.symbol_version, "gust-runtime-symbol-v1") == 0 { os.Exit(3); }
    os.LogStr("SUCCESS: Phase 17.2 runtime symbol version smoke passed");
}
