// Phase 17.11 native smoke: I/O, filesystem, directory, and resource audit.
//
// Freezes 22 selected operations. Sockets, processes, and terminals are deferred
// by the scope-selection rule, so os_RunProcess and os_System are concrete
// deferred rows rather than silent omissions. The load-bearing invariant is that
// an acquired resource kind must have exactly one close, and manual close and
// deferred cleanup must name the same runtime operation.

import "mir_runtime_boundary_authority.gst" as runtime;
import "mir_io_runtime_request.gst" as io_request;

func io_target_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func io_with(
    table: runtime.MirRuntimeBoundaryAuthorityTable[ctx],
    abi: runtime.MirRuntimeAbiIdentity[ctx],
    component: runtime.MirRuntimeComponentIdentity[ctx],
    spelling: str,
    io_kind: str,
    resource_kind: str,
    resource_transition: str,
    failure_form: str,
    filesystem_effect: str,
    close_operation_id: str,
    ordinal: int,
    ctx: &Arena
) runtime.MirRuntimeBoundaryAuthorityTable[ctx] {
    mut target_id := io_target_id();
    mut result := table;

    mut helper: runtime.MirRuntimeHelperIdentity[ctx];
    helper.helper_id = runtime.mir_runtime_helper_identity_id(spelling, target_id, ordinal, ctx);
    helper.operation_id = spelling;
    helper.symbol_identity = spelling;
    helper.source_location = "src/runtime";
    helper.target_applicability = "all_declared_host_targets_from_phase14_target_authority";
    result = runtime.mir_runtime_table_with_helper(result, helper, ctx);

    mut classification: runtime.MirRuntimeHelperClassification[ctx];
    classification.classification_id = runtime.mir_runtime_classification_id(helper.helper_id, ordinal, ctx);
    classification.helper_id = helper.helper_id;
    classification.classification = "retained_c_runtime_component";
    classification.component_id = component.component_id;
    classification.reason_code = "runtime_helper_classified_retained_c_component";
    result = runtime.mir_runtime_table_with_classification(result, classification, ctx);

    mut symbol: runtime.MirRuntimeSymbolIdentity[ctx];
    symbol.symbol_id = runtime.mir_runtime_symbol_identity_id(helper.helper_id, "gust-runtime-symbol-v1", target_id, ordinal, ctx);
    symbol.helper_id = helper.helper_id;
    symbol.external_spelling = spelling;
    symbol.symbol_version = "gust-runtime-symbol-v1";
    symbol.component_id = component.component_id;
    symbol.runtime_abi_id = abi.runtime_abi_id;
    mut function_abi_id := "function_abi:runtime:";
    function_abi_id = std.Concat(function_abi_id, spelling);
    function_abi_id = std.Concat(function_abi_id, ":i32_to_i32:gust_canonical_v1");
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
    result = runtime.mir_runtime_table_with_symbol(result, symbol, ctx);

    mut contract: runtime.MirRuntimeIoContract[ctx];
    contract.io_contract_id = runtime.mir_runtime_io_contract_id(helper.helper_id, io_kind, target_id, ordinal, ctx);
    contract.helper_id = helper.helper_id;
    contract.symbol_id = symbol.symbol_id;
    contract.io_kind = io_kind;
    contract.resource_kind = resource_kind;
    contract.resource_transition = resource_transition;
    contract.failure_form = failure_form;
    contract.filesystem_effect = filesystem_effect;
    contract.close_operation_id = close_operation_id;
    contract.target_id = target_id;
    return runtime.mir_runtime_table_with_io_contract(result, contract, ctx);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_id := io_target_id();
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
    component.component_id = runtime.mir_runtime_component_identity_id("retained_c_runtime_component", target_id, 0, &ctx);
    component.component_kind = "retained_c_runtime_component";
    component.source_path = "src/runtime/file_io.c";
    component.object_identity = "runtime:file_io";
    component.target_id = target_id;
    table = runtime.mir_runtime_table_with_component(table, component, &ctx);

    table = io_with(table, abi, component, "os_LogStr", "standard_stream", "none", "not_a_resource", "total_cannot_fail", "none", "", 0, &ctx);
    table = io_with(table, abi, component, "os_LogError", "standard_stream", "none", "not_a_resource", "total_cannot_fail", "none", "", 1, &ctx);
    table = io_with(table, abi, component, "os_LogInt", "standard_stream", "none", "not_a_resource", "total_cannot_fail", "none", "", 2, &ctx);
    table = io_with(table, abi, component, "os_ReadFile", "file_or_stream", "none", "not_a_resource", "returns_explicit_error", "reads_filesystem", "", 3, &ctx);
    table = io_with(table, abi, component, "os_WriteFile", "file_or_stream", "none", "not_a_resource", "returns_explicit_error", "writes_filesystem", "", 4, &ctx);
    table = io_with(table, abi, component, "os_read_stream_to_arena", "file_or_stream", "none", "not_a_resource", "returns_explicit_error", "reads_filesystem", "", 5, &ctx);
    table = io_with(table, abi, component, "os_path_join", "path_or_filesystem", "none", "not_a_resource", "returns_explicit_error", "none", "", 6, &ctx);
    table = io_with(table, abi, component, "os_PathAbsolute", "path_or_filesystem", "none", "not_a_resource", "returns_explicit_error", "reads_filesystem", "", 7, &ctx);
    table = io_with(table, abi, component, "os_PathDir", "path_or_filesystem", "none", "not_a_resource", "returns_explicit_error", "none", "", 8, &ctx);
    table = io_with(table, abi, component, "os_FileExists", "path_or_filesystem", "none", "not_a_resource", "total_cannot_fail", "reads_filesystem", "", 9, &ctx);
    table = io_with(table, abi, component, "os_FileExecutable", "path_or_filesystem", "none", "not_a_resource", "total_cannot_fail", "reads_filesystem", "", 10, &ctx);
    table = io_with(table, abi, component, "os_RemoveFile", "path_or_filesystem", "none", "not_a_resource", "returns_explicit_error", "removes_path", "", 11, &ctx);
    table = io_with(table, abi, component, "os_ExecutablePath", "path_or_filesystem", "none", "not_a_resource", "returns_explicit_error", "reads_filesystem", "", 12, &ctx);
    table = io_with(table, abi, component, "os_OpenDir", "directory_resource", "directory_handle", "acquires", "returns_explicit_error", "reads_filesystem", "runtime_close:directory_handle", 13, &ctx);
    table = io_with(table, abi, component, "os_ReadDir", "directory_resource", "directory_handle", "uses_borrowed", "returns_explicit_error", "reads_filesystem", "runtime_close:directory_handle", 14, &ctx);
    table = io_with(table, abi, component, "os_CloseDir", "directory_resource", "directory_handle", "closes", "total_cannot_fail", "none", "runtime_close:directory_handle", 15, &ctx);
    table = io_with(table, abi, component, "os_GetEnv", "environment_query", "none", "not_a_resource", "returns_explicit_error", "none", "", 16, &ctx);
    table = io_with(table, abi, component, "os_Args", "environment_query", "none", "not_a_resource", "total_cannot_fail", "none", "", 17, &ctx);
    table = io_with(table, abi, component, "os_NativeTargetTriple", "target_query", "none", "not_a_resource", "total_cannot_fail", "none", "", 18, &ctx);
    table = io_with(table, abi, component, "os_NativeObjectFormat", "target_query", "none", "not_a_resource", "total_cannot_fail", "none", "", 19, &ctx);
    table = io_with(table, abi, component, "os_copy_c_string_to_arena", "c_string_marshalling", "none", "not_a_resource", "returns_explicit_error", "none", "", 20, &ctx);
    table = io_with(table, abi, component, "os_slice_to_c_string", "c_string_marshalling", "none", "not_a_resource", "returns_explicit_error", "none", "", 21, &ctx);

    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    mut contracts: std.Vector[runtime.MirRuntimeIoContract[ctx], ctx] := ctx[table.io_contracts];
    if len(contracts) != 22 { os.Exit(2); }

    mut open_query := runtime.mir_runtime_io_contract_for(table, runtime.mir_runtime_helper_identity_id("os_OpenDir", target_id, 13, &ctx), &ctx);
    if open_query.found == 0 || std.str_eq(open_query.value.resource_transition, "acquires") == 0 { os.Exit(3); }
    if std.str_eq(open_query.value.resource_kind, "directory_handle") == 0 { os.Exit(4); }
    mut absent := runtime.mir_runtime_io_contract_for(table, "p17_helper_not_selected", &ctx);
    if absent.found == 1 { os.Exit(5); }

    mut request := io_request.mir_serialize_io_runtime_request(table, &ctx);
    mut witness := io_request.mir_io_runtime_mir_to_c_witness(table, &ctx);
    if os.WriteFile("/tmp/gust-phase17-io-runtime.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase17-io-runtime.mir-to-c.witness", witness) == 0 { os.Exit(6); }

    // Rejection: a directory acquired with no matching close.
    mut leak_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    leak_table = runtime.mir_runtime_table_with_abi(leak_table, abi, &ctx);
    leak_table = runtime.mir_runtime_table_with_component(leak_table, component, &ctx);
    leak_table = io_with(leak_table, abi, component, "os_OpenDir", "directory_resource", "directory_handle", "acquires", "returns_explicit_error", "reads_filesystem", "runtime_close:directory_handle", 0, &ctx);
    mut leak_validation := runtime.mir_runtime_boundary_authority_table_validate(leak_table, &ctx);
    if leak_validation.valid == 1 || std.str_eq(leak_validation.reason_code, "runtime_io_close_mismatch") == 0 { os.Exit(7); }

    // Rejection: two closers for the same resource kind.
    mut double_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    double_table = runtime.mir_runtime_table_with_abi(double_table, abi, &ctx);
    double_table = runtime.mir_runtime_table_with_component(double_table, component, &ctx);
    double_table = io_with(double_table, abi, component, "os_CloseDir", "directory_resource", "directory_handle", "closes", "total_cannot_fail", "none", "runtime_close:directory_handle", 0, &ctx);
    double_table = io_with(double_table, abi, component, "os_CloseDirAgain", "directory_resource", "directory_handle", "closes", "total_cannot_fail", "none", "runtime_close:directory_handle", 1, &ctx);
    mut double_validation := runtime.mir_runtime_boundary_authority_table_validate(double_table, &ctx);
    if double_validation.valid == 1 || std.str_eq(double_validation.reason_code, "runtime_io_duplicate_close") == 0 { os.Exit(8); }

    // Rejection: a non-resource helper claiming a resource transition.
    mut wrong_kind_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    wrong_kind_table = runtime.mir_runtime_table_with_abi(wrong_kind_table, abi, &ctx);
    wrong_kind_table = runtime.mir_runtime_table_with_component(wrong_kind_table, component, &ctx);
    wrong_kind_table = io_with(wrong_kind_table, abi, component, "os_ReadFile", "file_or_stream", "none", "acquires", "returns_explicit_error", "reads_filesystem", "", 0, &ctx);
    mut wrong_kind_validation := runtime.mir_runtime_boundary_authority_table_validate(wrong_kind_table, &ctx);
    if wrong_kind_validation.valid == 1 || std.str_eq(wrong_kind_validation.reason_code, "runtime_io_wrong_resource_kind") == 0 { os.Exit(9); }

    // Rejection: an I/O kind outside the selected inventory.
    mut bad_kind_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    bad_kind_table = runtime.mir_runtime_table_with_abi(bad_kind_table, abi, &ctx);
    bad_kind_table = runtime.mir_runtime_table_with_component(bad_kind_table, component, &ctx);
    bad_kind_table = io_with(bad_kind_table, abi, component, "os_Socket", "network_socket", "none", "not_a_resource", "returns_explicit_error", "none", "", 0, &ctx);
    mut bad_kind_validation := runtime.mir_runtime_boundary_authority_table_validate(bad_kind_table, &ctx);
    if bad_kind_validation.valid == 1 || std.str_eq(bad_kind_validation.reason_code, "runtime_io_unsupported_target") == 0 { os.Exit(10); }

    os.LogStr("SUCCESS: Phase 17.11 io filesystem resource smoke passed");
}
