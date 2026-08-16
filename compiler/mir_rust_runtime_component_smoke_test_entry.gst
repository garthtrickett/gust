// Phase 17.6 native smoke: Rust runtime components as explicit, versioned
// runtime package members.
//
// Builds one reference Rust component (src/runtime/rust), proves its exports are
// compiler-owned symbols with declared panic and allocation boundaries, and
// asserts the validator rejects undeclared exports, unwind-capable boundaries,
// ABI or target mismatch, duplicate symbol providers, and hidden dependencies on
// generated C glue.

import "mir_runtime_boundary_authority.gst" as runtime;
import "mir_rust_runtime_request.gst" as rust_request;

func rust_target_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func rust_applicability() str {
    return "all_declared_host_targets_from_phase14_target_authority";
}

func rust_strings(first: str, second: str, ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut result := runtime.mir_runtime_empty_strings(ctx);
    mut values: std.Vector[str, ctx] := ctx[result];
    if len(first) != 0 { values.Push(first); }
    if len(second) != 0 { values.Push(second); }
    ctx.Set(result, values);
    return result;
}

func rust_make_symbol(
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

// A fresh table carrying one Rust component, so a negative assertion reports the
// defect under test rather than a duplicate-row conflict from a shared table.
func rust_table(
    abi: runtime.MirRuntimeAbiIdentity[ctx],
    component: runtime.MirRuntimeComponentIdentity[ctx],
    helper: runtime.MirRuntimeHelperIdentity[ctx],
    classification: runtime.MirRuntimeHelperClassification[ctx],
    symbol: runtime.MirRuntimeSymbolIdentity[ctx],
    rust: runtime.MirRuntimeRustComponent[ctx],
    ctx: &Arena
) runtime.MirRuntimeBoundaryAuthorityTable[ctx] {
    mut result := runtime.mir_runtime_make_empty_table(rust_target_id(), "x86_64-unknown-linux-gnu", ctx);
    result = runtime.mir_runtime_table_with_abi(result, abi, ctx);
    result = runtime.mir_runtime_table_with_component(result, component, ctx);
    result = runtime.mir_runtime_table_with_helper(result, helper, ctx);
    result = runtime.mir_runtime_table_with_classification(result, classification, ctx);
    result = runtime.mir_runtime_table_with_symbol(result, symbol, ctx);
    return runtime.mir_runtime_table_with_rust_component(result, rust, ctx);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_id := rust_target_id();

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
    component.component_id = runtime.mir_runtime_component_identity_id("rust_runtime_component", target_id, 0, &ctx);
    component.component_kind = "rust_runtime_component";
    component.source_path = "src/runtime/rust/src/lib.rs";
    component.object_identity = "runtime:rust_scalar_support";
    component.target_id = target_id;

    mut helper: runtime.MirRuntimeHelperIdentity[ctx];
    helper.helper_id = runtime.mir_runtime_helper_identity_id("gust_rt_saturating_add_i32", target_id, 0, &ctx);
    helper.operation_id = "gust_rt_saturating_add_i32";
    helper.symbol_identity = "gust_rt_saturating_add_i32";
    helper.source_location = "src/runtime/rust/src/lib.rs:41";
    helper.target_applicability = rust_applicability();

    mut classification: runtime.MirRuntimeHelperClassification[ctx];
    classification.classification_id = runtime.mir_runtime_classification_id(helper.helper_id, 0, &ctx);
    classification.helper_id = helper.helper_id;
    classification.classification = "rust_runtime_component";
    classification.component_id = component.component_id;
    classification.reason_code = "runtime_helper_classified_rust_component";

    mut symbol := rust_make_symbol(helper.helper_id, "gust_rt_saturating_add_i32", "i32_i32_to_i32", component.component_id, abi.runtime_abi_id, target_id, 0, &ctx);

    mut rust: runtime.MirRuntimeRustComponent[ctx];
    rust.rust_component_id = runtime.mir_runtime_rust_component_id(component.component_id, abi.runtime_abi_id, target_id, 0, &ctx);
    rust.component_id = component.component_id;
    rust.source_ownership = "repository_owned_src_runtime_rust";
    rust.exported_symbol_ids = rust_strings(symbol.symbol_id, "", &ctx);
    rust.imported_symbol_ids = rust_strings("", "", &ctx);
    rust.runtime_abi_id = abi.runtime_abi_id;
    rust.target_id = target_id;
    rust.target_applicability = rust_applicability();
    rust.object_form = "static_library";
    rust.panic_boundary = "abort_no_unwind_across_ffi";
    rust.allocation_boundary = "no_allocation_caller_owns_all_memory";

    mut table := rust_table(abi, component, helper, classification, symbol, rust, &ctx);
    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    mut query := runtime.mir_runtime_rust_component_for(table, component.component_id, &ctx);
    if query.found == 0 { os.Exit(2); }
    if std.str_eq(query.value.panic_boundary, "abort_no_unwind_across_ffi") == 0 { os.Exit(3); }
    if std.str_eq(query.value.object_form, "static_library") == 0 { os.Exit(4); }
    mut absent := runtime.mir_runtime_rust_component_for(table, "runtime_component:not_rust", &ctx);
    if absent.found == 1 { os.Exit(5); }

    mut serialized := runtime.mir_serialize_runtime_boundary_authority_table_for_request(table, &ctx);
    if std.str_find(serialized, "runtime_rust_panic_boundary: abort_no_unwind_across_ffi") == 0 - 1 { os.Exit(6); }
    if std.str_find(serialized, "runtime_rust_object_form: static_library") == 0 - 1 { os.Exit(7); }

    // Rejection: an export the compiler does not own.
    mut undeclared := rust;
    undeclared.exported_symbol_ids = rust_strings("runtime_symbol:v1:helper=not_compiler_owned", "", &ctx);
    mut undeclared_validation := runtime.mir_runtime_boundary_authority_table_validate(
        rust_table(abi, component, helper, classification, symbol, undeclared, &ctx), &ctx);
    if undeclared_validation.valid == 1 || std.str_eq(undeclared_validation.reason_code, "runtime_rust_undeclared_export") == 0 { os.Exit(8); }

    // Rejection: a panic boundary that permits unwinding across the FFI edge.
    mut unwinding := rust;
    unwinding.panic_boundary = "unwind_into_caller";
    mut unwinding_validation := runtime.mir_runtime_boundary_authority_table_validate(
        rust_table(abi, component, helper, classification, symbol, unwinding, &ctx), &ctx);
    if unwinding_validation.valid == 1 || std.str_eq(unwinding_validation.reason_code, "runtime_rust_unwind_boundary_violation") == 0 { os.Exit(9); }

    // Rejection: an object form outside the declared inventory.
    mut wrong_form := rust;
    wrong_form.object_form = "dynamic_library";
    mut wrong_form_validation := runtime.mir_runtime_boundary_authority_table_validate(
        rust_table(abi, component, helper, classification, symbol, wrong_form, &ctx), &ctx);
    if wrong_form_validation.valid == 1 || std.str_eq(wrong_form_validation.reason_code, "runtime_rust_abi_or_target_mismatch") == 0 { os.Exit(10); }

    // Rejection: a hidden dependency on generated C glue.
    mut glued := rust;
    glued.imported_symbol_ids = rust_strings("runtime_symbol:v1:generated_c_shim_helper", "", &ctx);
    mut glued_validation := runtime.mir_runtime_boundary_authority_table_validate(
        rust_table(abi, component, helper, classification, symbol, glued, &ctx), &ctx);
    if glued_validation.valid == 1 || std.str_eq(glued_validation.reason_code, "runtime_rust_generated_c_glue_dependency") == 0 { os.Exit(11); }

    // Rejection: two components providing the same exported symbol.
    mut second := rust;
    second.rust_component_id = runtime.mir_runtime_rust_component_id(component.component_id, abi.runtime_abi_id, target_id, 1, &ctx);
    mut duplicate_table := runtime.mir_runtime_table_with_rust_component(
        rust_table(abi, component, helper, classification, symbol, rust, &ctx), second, &ctx);
    mut duplicate_validation := runtime.mir_runtime_boundary_authority_table_validate(duplicate_table, &ctx);
    if duplicate_validation.valid == 1 || std.str_eq(duplicate_validation.reason_code, "runtime_rust_duplicate_symbol_provider") == 0 { os.Exit(12); }

    mut request := rust_request.mir_serialize_rust_runtime_request(table, &ctx);
    mut witness := rust_request.mir_rust_runtime_mir_to_c_witness(table, &ctx);
    if os.WriteFile("/tmp/gust-phase17-rust-runtime.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase17-rust-runtime.mir-to-c.witness", witness) == 0
    {
        os.Exit(13);
    }
    if std.str_find(witness, "linkage=independently_compiled_component_no_source_specific_c_generation") == 0 - 1 { os.Exit(14); }

    os.LogStr("SUCCESS: Phase 17.6 rust runtime component smoke passed");
}
