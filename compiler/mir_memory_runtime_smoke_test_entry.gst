// Phase 17.10 native smoke: allocation, core-memory, and string runtime audit.
//
// Freezes 26 selected operations across four allocation domains and proves the
// load-bearing invariant: memory obtained from one domain may only be released
// through the same domain. os_LogInt lives in arena.c but is logging rather than
// memory, so it is a concrete deferred row for Patch 17.11 rather than a
// misclassified memory operation.

import "mir_runtime_boundary_authority.gst" as runtime;
import "mir_memory_runtime_request.gst" as memory_request;

func memory_target_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func memory_applicability() str {
    return "all_declared_host_targets_from_phase14_target_authority";
}

// Adds the helper, classification, symbol, and memory contract for one selected
// operation, so the fixture declares the same chain the compiler would.
func memory_with(
    table: runtime.MirRuntimeBoundaryAuthorityTable[ctx],
    abi: runtime.MirRuntimeAbiIdentity[ctx],
    component: runtime.MirRuntimeComponentIdentity[ctx],
    spelling: str,
    operation_kind: str,
    allocation_domain: str,
    ownership_transfer: str,
    failure_reporting: str,
    ordinal: int,
    ctx: &Arena
) runtime.MirRuntimeBoundaryAuthorityTable[ctx] {
    mut target_id := memory_target_id();
    mut result := table;

    mut helper: runtime.MirRuntimeHelperIdentity[ctx];
    helper.helper_id = runtime.mir_runtime_helper_identity_id(spelling, target_id, ordinal, ctx);
    helper.operation_id = spelling;
    helper.symbol_identity = spelling;
    helper.source_location = "src/runtime";
    helper.target_applicability = memory_applicability();
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

    mut contract: runtime.MirRuntimeMemoryContract[ctx];
    contract.memory_contract_id = runtime.mir_runtime_memory_contract_id(helper.helper_id, operation_kind, target_id, ordinal, ctx);
    contract.helper_id = helper.helper_id;
    contract.symbol_id = symbol.symbol_id;
    contract.operation_kind = operation_kind;
    contract.allocation_domain = allocation_domain;
    contract.ownership_transfer = ownership_transfer;
    contract.failure_reporting = failure_reporting;
    contract.layout_id = symbol.layout_id;
    contract.resource_operation_id = symbol.resource_operation_id;
    contract.target_id = target_id;
    return runtime.mir_runtime_table_with_memory_contract(result, contract, ctx);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_id := memory_target_id();
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
    component.source_path = "src/runtime/arena.c";
    component.object_identity = "runtime:arena";
    component.target_id = target_id;
    table = runtime.mir_runtime_table_with_component(table, component, &ctx);

    table = memory_with(table, abi, component, "os_Arena_New", "allocate", "host_process_allocator", "ownership_transfers_to_caller", "returns_explicit_error", 0, &ctx);
    table = memory_with(table, abi, component, "os_Arena_Free", "deallocate", "host_process_allocator", "caller_retains_ownership", "total_cannot_fail", 1, &ctx);
    table = memory_with(table, abi, component, "os_ArenaAlloc", "allocate", "caller_owned_arena", "ownership_transfers_to_caller", "returns_explicit_error", 2, &ctx);
    table = memory_with(table, abi, component, "os_Arena_Validate", "bounds_or_failure_report", "no_allocation", "borrowed_for_call_duration", "aborts_process_on_failure", 3, &ctx);
    table = memory_with(table, abi, component, "std_GenerationalSwap", "memory_move", "caller_owned_arena", "caller_retains_ownership", "total_cannot_fail", 4, &ctx);
    table = memory_with(table, abi, component, "os_ScratchAlloc", "allocate", "thread_local_scratch", "ownership_transfers_to_caller", "returns_explicit_error", 5, &ctx);
    table = memory_with(table, abi, component, "os_ScratchReset", "deallocate", "thread_local_scratch", "caller_retains_ownership", "total_cannot_fail", 6, &ctx);
    table = memory_with(table, abi, component, "os_SetThreadScratch", "memory_set", "no_allocation", "borrowed_for_call_duration", "total_cannot_fail", 7, &ctx);
    table = memory_with(table, abi, component, "os_GetThreadScratch_raw", "bounds_or_failure_report", "no_allocation", "borrowed_for_call_duration", "total_cannot_fail", 8, &ctx);
    table = memory_with(table, abi, component, "std_PoolAlloc_impl", "allocate", "caller_owned_arena", "ownership_transfers_to_caller", "returns_explicit_error", 9, &ctx);
    table = memory_with(table, abi, component, "std_PoolFree_impl", "deallocate", "caller_owned_arena", "caller_retains_ownership", "total_cannot_fail", 10, &ctx);
    table = memory_with(table, abi, component, "os_HashMapRef_impl", "memory_copy", "caller_owned_arena", "borrowed_for_call_duration", "returns_explicit_error", 11, &ctx);
    table = memory_with(table, abi, component, "os_HashMapContains_impl", "memory_compare", "no_allocation", "borrowed_for_call_duration", "total_cannot_fail", 12, &ctx);
    table = memory_with(table, abi, component, "os_HashMapRemove_impl", "memory_set", "caller_owned_arena", "caller_retains_ownership", "total_cannot_fail", 13, &ctx);
    table = memory_with(table, abi, component, "os_HashMapClear_impl", "memory_set", "caller_owned_arena", "caller_retains_ownership", "total_cannot_fail", 14, &ctx);
    table = memory_with(table, abi, component, "std_Clone_str", "string_create", "caller_owned_arena", "ownership_transfers_to_caller", "returns_explicit_error", 15, &ctx);
    table = memory_with(table, abi, component, "std_str_eq", "string_compare", "no_allocation", "borrowed_for_call_duration", "total_cannot_fail", 16, &ctx);
    table = memory_with(table, abi, component, "std_str_byte_at", "string_length", "no_allocation", "borrowed_for_call_duration", "total_cannot_fail", 17, &ctx);
    table = memory_with(table, abi, component, "std_str_slice", "string_convert", "no_allocation", "borrowed_for_call_duration", "total_cannot_fail", 18, &ctx);
    table = memory_with(table, abi, component, "std_str_find", "string_compare", "no_allocation", "borrowed_for_call_duration", "total_cannot_fail", 19, &ctx);
    table = memory_with(table, abi, component, "std_str_trim", "string_convert", "no_allocation", "borrowed_for_call_duration", "total_cannot_fail", 20, &ctx);
    table = memory_with(table, abi, component, "std_str_split", "string_create", "caller_owned_arena", "ownership_transfers_to_caller", "returns_explicit_error", 21, &ctx);
    table = memory_with(table, abi, component, "std_parse_int", "string_convert", "no_allocation", "borrowed_for_call_duration", "returns_explicit_error", 22, &ctx);
    table = memory_with(table, abi, component, "std_is_alpha", "string_compare", "no_allocation", "borrowed_for_call_duration", "total_cannot_fail", 23, &ctx);
    table = memory_with(table, abi, component, "std_is_digit", "string_compare", "no_allocation", "borrowed_for_call_duration", "total_cannot_fail", 24, &ctx);
    table = memory_with(table, abi, component, "std_is_whitespace", "string_compare", "no_allocation", "borrowed_for_call_duration", "total_cannot_fail", 25, &ctx);

    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    mut contracts: std.Vector[runtime.MirRuntimeMemoryContract[ctx], ctx] := ctx[table.memory_contracts];
    if len(contracts) != 26 { os.Exit(2); }

    // Each allocating domain has a matched release in the same domain.
    mut allocator_query := runtime.mir_runtime_memory_contract_for(table, runtime.mir_runtime_helper_identity_id("os_Arena_New", target_id, 0, &ctx), &ctx);
    if allocator_query.found == 0 || std.str_eq(allocator_query.value.allocation_domain, "host_process_allocator") == 0 { os.Exit(3); }
    if std.str_eq(allocator_query.value.ownership_transfer, "ownership_transfers_to_caller") == 0 { os.Exit(4); }
    mut absent := runtime.mir_runtime_memory_contract_for(table, "p17_helper_not_selected", &ctx);
    if absent.found == 1 { os.Exit(5); }

    mut request := memory_request.mir_serialize_memory_runtime_request(table, &ctx);
    mut witness := memory_request.mir_memory_runtime_mir_to_c_witness(table, &ctx);
    if os.WriteFile("/tmp/gust-phase17-memory-runtime.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase17-memory-runtime.mir-to-c.witness", witness) == 0 { os.Exit(6); }

    // Rejection: a release with no acquisition in the same domain.
    mut orphan_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    orphan_table = runtime.mir_runtime_table_with_abi(orphan_table, abi, &ctx);
    orphan_table = runtime.mir_runtime_table_with_component(orphan_table, component, &ctx);
    orphan_table = memory_with(orphan_table, abi, component, "os_Arena_Free", "deallocate", "host_process_allocator", "caller_retains_ownership", "total_cannot_fail", 0, &ctx);
    mut orphan_validation := runtime.mir_runtime_boundary_authority_table_validate(orphan_table, &ctx);
    if orphan_validation.valid == 1 || std.str_eq(orphan_validation.reason_code, "runtime_memory_incompatible_allocator_domain") == 0 { os.Exit(7); }

    // Rejection: an allocation domain outside the declared inventory.
    mut bad_domain_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    bad_domain_table = runtime.mir_runtime_table_with_abi(bad_domain_table, abi, &ctx);
    bad_domain_table = runtime.mir_runtime_table_with_component(bad_domain_table, component, &ctx);
    bad_domain_table = memory_with(bad_domain_table, abi, component, "os_ArenaAlloc", "allocate", "some_other_heap", "ownership_transfers_to_caller", "returns_explicit_error", 0, &ctx);
    mut bad_domain_validation := runtime.mir_runtime_boundary_authority_table_validate(bad_domain_table, &ctx);
    if bad_domain_validation.valid == 1 || std.str_eq(bad_domain_validation.reason_code, "runtime_memory_incompatible_allocator_domain") == 0 { os.Exit(8); }

    // Rejection: an operation kind outside the selected inventory.
    mut bad_op_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    bad_op_table = runtime.mir_runtime_table_with_abi(bad_op_table, abi, &ctx);
    bad_op_table = runtime.mir_runtime_table_with_component(bad_op_table, component, &ctx);
    bad_op_table = memory_with(bad_op_table, abi, component, "os_ArenaAlloc", "garbage_collect", "caller_owned_arena", "ownership_transfers_to_caller", "returns_explicit_error", 0, &ctx);
    mut bad_op_validation := runtime.mir_runtime_boundary_authority_table_validate(bad_op_table, &ctx);
    if bad_op_validation.valid == 1 || std.str_eq(bad_op_validation.reason_code, "runtime_memory_unsupported_target_operation") == 0 { os.Exit(9); }

    os.LogStr("SUCCESS: Phase 17.10 allocation string memory smoke passed");
}
