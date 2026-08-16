// Phase 17.8 native smoke: the pure Gust runtime module compiles and behaves
// through the ordinary generic route, with no bespoke compiler recognition.

import "../src/runtime/gust/char_predicates.gst" as chars;
import "mir_runtime_boundary_authority.gst" as runtime;
import "mir_gust_runtime_request.gst" as gust_request;

func gust_target_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func gust_applicability() str {
    return "all_declared_host_targets_from_phase14_target_authority";
}

func gust_strings(first: str, second: str, ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut result := runtime.mir_runtime_empty_strings(ctx);
    mut values: std.Vector[str, ctx] := ctx[result];
    if len(first) != 0 { values.Push(first); }
    if len(second) != 0 { values.Push(second); }
    ctx.Set(result, values);
    return result;
}

func gust_make_symbol(helper_id: str, spelling: str, signature: str, component_id: str, runtime_abi_id: str, target_id: str, ordinal: int, ctx: &Arena) runtime.MirRuntimeSymbolIdentity[ctx] {
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

func gust_table(
    abi: runtime.MirRuntimeAbiIdentity[ctx],
    component: runtime.MirRuntimeComponentIdentity[ctx],
    helper: runtime.MirRuntimeHelperIdentity[ctx],
    classification: runtime.MirRuntimeHelperClassification[ctx],
    symbol: runtime.MirRuntimeSymbolIdentity[ctx],
    module: runtime.MirRuntimeGustModule[ctx],
    ctx: &Arena
) runtime.MirRuntimeBoundaryAuthorityTable[ctx] {
    mut result := runtime.mir_runtime_make_empty_table(gust_target_id(), "x86_64-unknown-linux-gnu", ctx);
    result = runtime.mir_runtime_table_with_abi(result, abi, ctx);
    result = runtime.mir_runtime_table_with_component(result, component, ctx);
    result = runtime.mir_runtime_table_with_helper(result, helper, ctx);
    result = runtime.mir_runtime_table_with_classification(result, classification, ctx);
    result = runtime.mir_runtime_table_with_symbol(result, symbol, ctx);
    return runtime.mir_runtime_table_with_gust_module(result, module, ctx);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    if chars.gust_rt_is_digit(48) == 0 || chars.gust_rt_is_digit(57) == 0 { os.Exit(1); }
    if chars.gust_rt_is_digit(47) == 1 || chars.gust_rt_is_digit(58) == 1 { os.Exit(2); }
    if chars.gust_rt_is_alpha(97) == 0 || chars.gust_rt_is_alpha(90) == 0 { os.Exit(3); }
    if chars.gust_rt_is_alpha(64) == 1 || chars.gust_rt_is_alpha(123) == 1 { os.Exit(4); }
    if chars.gust_rt_is_whitespace(32) == 0 || chars.gust_rt_is_whitespace(10) == 0 { os.Exit(5); }
    if chars.gust_rt_is_whitespace(65) == 1 { os.Exit(6); }
    if chars.gust_rt_is_alphanumeric(53) == 0 || chars.gust_rt_is_alphanumeric(122) == 0 { os.Exit(7); }
    if chars.gust_rt_is_alphanumeric(33) == 1 { os.Exit(8); }

    // The module above is ordinary Gust that already compiled through the
    // generic route. What follows proves the compiler-owned declaration of it.
    mut target_id := gust_target_id();
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
    component.component_id = runtime.mir_runtime_component_identity_id("pure_gust_runtime_component", target_id, 0, &ctx);
    component.component_kind = "pure_gust_runtime_component";
    component.source_path = "src/runtime/gust/char_predicates.gst";
    component.object_identity = "runtime:gust_char_predicates";
    component.target_id = target_id;

    mut helper: runtime.MirRuntimeHelperIdentity[ctx];
    helper.helper_id = runtime.mir_runtime_helper_identity_id("gust_rt_is_alpha", target_id, 0, &ctx);
    helper.operation_id = "gust_rt_is_alpha";
    helper.symbol_identity = "gust_rt_is_alpha";
    helper.source_location = "src/runtime/gust/char_predicates.gst:31";
    helper.target_applicability = gust_applicability();

    mut classification: runtime.MirRuntimeHelperClassification[ctx];
    classification.classification_id = runtime.mir_runtime_classification_id(helper.helper_id, 0, &ctx);
    classification.helper_id = helper.helper_id;
    classification.classification = "pure_gust_runtime_component";
    classification.component_id = component.component_id;
    classification.reason_code = "runtime_helper_classified_pure_gust_component";

    mut symbol := gust_make_symbol(helper.helper_id, "gust_rt_is_alpha", "i32_to_i32", component.component_id, abi.runtime_abi_id, target_id, 0, &ctx);

    mut module: runtime.MirRuntimeGustModule[ctx];
    module.gust_module_id = runtime.mir_runtime_gust_module_id(component.component_id, abi.runtime_abi_id, target_id, 0, &ctx);
    module.component_id = component.component_id;
    module.module_source_path = "src/runtime/gust/char_predicates.gst";
    module.exported_symbol_ids = gust_strings(symbol.symbol_id, "", &ctx);
    module.imported_symbol_ids = gust_strings("", "", &ctx);
    module.allowed_dependency_ids = gust_strings("", "", &ctx);
    module.runtime_abi_id = abi.runtime_abi_id;
    module.target_id = target_id;
    module.target_applicability = gust_applicability();
    module.lowering_route = "generic_parse_typecheck_canonical_mir_abi_cranelift";
    module.initialization_policy = "none_required_pure_functions";
    module.failure_policy = "total_cannot_fail";

    mut table := gust_table(abi, component, helper, classification, symbol, module, &ctx);
    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(9); }

    mut query := runtime.mir_runtime_gust_module_for(table, component.component_id, &ctx);
    if query.found == 0 { os.Exit(10); }
    if std.str_eq(query.value.lowering_route, "generic_parse_typecheck_canonical_mir_abi_cranelift") == 0 { os.Exit(11); }

    mut request := gust_request.mir_serialize_gust_runtime_request(table, &ctx);
    mut witness := gust_request.mir_gust_runtime_mir_to_c_witness(table, &ctx);
    if os.WriteFile("/tmp/gust-phase17-gust-runtime.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase17-gust-runtime.mir-to-c.witness", witness) == 0 { os.Exit(12); }

    // Rejection: a bespoke lowering path means the compiler recognised it.
    mut bespoke := module;
    bespoke.lowering_route = "runtime_module_special_case";
    mut bespoke_validation := runtime.mir_runtime_boundary_authority_table_validate(
        gust_table(abi, component, helper, classification, symbol, bespoke, &ctx), &ctx);
    if bespoke_validation.valid == 1 || std.str_eq(bespoke_validation.reason_code, "runtime_gust_non_generic_lowering") == 0 { os.Exit(13); }

    // Rejection: an export the compiler does not own.
    mut missing := module;
    missing.exported_symbol_ids = gust_strings("runtime_symbol:v1:helper=not_compiler_owned", "", &ctx);
    mut missing_validation := runtime.mir_runtime_boundary_authority_table_validate(
        gust_table(abi, component, helper, classification, symbol, missing, &ctx), &ctx);
    if missing_validation.valid == 1 || std.str_eq(missing_validation.reason_code, "runtime_gust_missing_requirement") == 0 { os.Exit(14); }

    // Rejection: a module depending on its own component.
    mut circular := module;
    circular.allowed_dependency_ids = gust_strings(component.component_id, "", &ctx);
    mut circular_validation := runtime.mir_runtime_boundary_authority_table_validate(
        gust_table(abi, component, helper, classification, symbol, circular, &ctx), &ctx);
    if circular_validation.valid == 1 || std.str_eq(circular_validation.reason_code, "runtime_gust_circular_dependency") == 0 { os.Exit(15); }

    // Rejection: source that is generated C rather than repository Gust.
    mut generated := module;
    generated.module_source_path = "build/generated/runtime_shim.c";
    mut generated_validation := runtime.mir_runtime_boundary_authority_table_validate(
        gust_table(abi, component, helper, classification, symbol, generated, &ctx), &ctx);
    if generated_validation.valid == 1 || std.str_eq(generated_validation.reason_code, "runtime_gust_hidden_generated_c") == 0 { os.Exit(16); }

    // Rejection: a target that is not the declared one.
    mut wrong_target := module;
    wrong_target.target_id = "target:v1:triple=aarch64-unknown-linux-gnu";
    mut wrong_target_validation := runtime.mir_runtime_boundary_authority_table_validate(
        gust_table(abi, component, helper, classification, symbol, wrong_target, &ctx), &ctx);
    if wrong_target_validation.valid == 1 || std.str_eq(wrong_target_validation.reason_code, "runtime_gust_abi_or_target_mismatch") == 0 { os.Exit(17); }

    os.LogStr("SUCCESS: Phase 17.8 gust runtime module smoke passed");
}
