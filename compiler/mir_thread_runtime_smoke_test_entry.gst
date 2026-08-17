// Phase 17.12 native smoke: threading and synchronization audit.
//
// Eleven selected operations. The load-bearing rule is that any platform thread
// library a helper depends on must be a permitted system import of a declared
// package, so pthread cannot arrive on the link line undeclared. Scheduler
// ordering is not made a stable oracle: gust_yield, gust_context_switch and the
// rest are concrete deferred rows under the scope-selection rule.

import "mir_runtime_boundary_authority.gst" as runtime;
import "mir_thread_runtime_request.gst" as thread_request;

func thread_target_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func thread_with(
    table: runtime.MirRuntimeBoundaryAuthorityTable[ctx],
    abi: runtime.MirRuntimeAbiIdentity[ctx],
    component: runtime.MirRuntimeComponentIdentity[ctx],
    package: runtime.MirRuntimePackageIdentity[ctx],
    spelling: str,
    thread_operation: str,
    system_library: str,
    lifetime_constraint: str,
    cancellation_policy: str,
    failure_form: str,
    ordinal: int,
    ctx: &Arena
) runtime.MirRuntimeBoundaryAuthorityTable[ctx] {
    mut target_id := thread_target_id();
    mut result := table;

    mut helper: runtime.MirRuntimeHelperIdentity[ctx];
    helper.helper_id = runtime.mir_runtime_helper_identity_id(spelling, target_id, ordinal, ctx);
    helper.operation_id = spelling;
    helper.symbol_identity = spelling;
    helper.source_location = "src/runtime/fiber.c";
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

    mut contract: runtime.MirRuntimeThreadContract[ctx];
    contract.thread_contract_id = runtime.mir_runtime_thread_contract_id(helper.helper_id, thread_operation, target_id, ordinal, ctx);
    contract.helper_id = helper.helper_id;
    contract.symbol_id = symbol.symbol_id;
    contract.thread_operation = thread_operation;
    contract.system_library_dependency = system_library;
    contract.lifetime_constraint = lifetime_constraint;
    contract.cancellation_policy = cancellation_policy;
    contract.failure_form = failure_form;
    contract.target_id = target_id;
    return runtime.mir_runtime_table_with_thread_contract(result, contract, ctx);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_id := thread_target_id();
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
    component.source_path = "src/runtime/fiber.c";
    component.object_identity = "runtime:fiber";
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

    // pthread is declared as a permitted system import of the package. Without
    // this row every pthread-dependent contract below is rejected.
    mut pthread_import: runtime.MirRuntimePackageSystemImport[ctx];
    pthread_import.import_id = runtime.mir_runtime_package_system_import_id(package.package_id, "pthread", 0, &ctx);
    pthread_import.package_id = package.package_id;
    pthread_import.external_spelling = "pthread";
    pthread_import.origin = "permitted_platform_thread_library";
    table = runtime.mir_runtime_table_with_package_system_import(table, pthread_import, &ctx);

    table = thread_with(table, abi, component, package, "std_Mutex_Alloc", "mutex_create", "pthread", "caller_scoped", "no_cancellation_supported", "returns_explicit_error", 0, &ctx);
    table = thread_with(table, abi, component, package, "std_Mutex_Lock_impl", "mutex_lock", "pthread", "caller_scoped", "no_cancellation_supported", "total_cannot_fail", 1, &ctx);
    table = thread_with(table, abi, component, package, "std_Mutex_Unlock_impl", "mutex_unlock", "pthread", "caller_scoped", "no_cancellation_supported", "total_cannot_fail", 2, &ctx);
    table = thread_with(table, abi, component, package, "std_Channel_Alloc", "channel_create", "none", "caller_scoped", "no_cancellation_supported", "returns_explicit_error", 3, &ctx);
    table = thread_with(table, abi, component, package, "std_Channel_Send_impl", "channel_send", "none", "caller_scoped", "cooperative_yield_point", "total_cannot_fail", 4, &ctx);
    table = thread_with(table, abi, component, package, "std_Channel_Recv_impl", "channel_receive", "none", "caller_scoped", "cooperative_yield_point", "total_cannot_fail", 5, &ctx);
    table = thread_with(table, abi, component, package, "gust_fiber_create", "fiber_create", "none", "scheduler_owned", "no_cancellation_supported", "returns_explicit_error", 6, &ctx);
    table = thread_with(table, abi, component, package, "gust_fiber_free", "fiber_destroy", "none", "scheduler_owned", "no_cancellation_supported", "total_cannot_fail", 7, &ctx);
    table = thread_with(table, abi, component, package, "gust_scheduler_init", "scheduler_init", "pthread", "process_lifetime", "no_cancellation_supported", "returns_explicit_error", 8, &ctx);
    table = thread_with(table, abi, component, package, "gust_scheduler_destroy", "scheduler_destroy", "pthread", "process_lifetime", "no_cancellation_supported", "total_cannot_fail", 9, &ctx);
    table = thread_with(table, abi, component, package, "get_num_threads_to_use", "thread_count_query", "pthread", "process_lifetime", "no_cancellation_supported", "total_cannot_fail", 10, &ctx);

    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    mut contracts: std.Vector[runtime.MirRuntimeThreadContract[ctx], ctx] := ctx[table.thread_contracts];
    if len(contracts) != 11 { os.Exit(2); }

    mut mutex_query := runtime.mir_runtime_thread_contract_for(table, runtime.mir_runtime_helper_identity_id("std_Mutex_Alloc", target_id, 0, &ctx), &ctx);
    if mutex_query.found == 0 || std.str_eq(mutex_query.value.system_library_dependency, "pthread") == 0 { os.Exit(3); }
    if std.str_eq(mutex_query.value.cancellation_policy, "no_cancellation_supported") == 0 { os.Exit(4); }
    mut absent := runtime.mir_runtime_thread_contract_for(table, "p17_helper_not_selected", &ctx);
    if absent.found == 1 { os.Exit(5); }

    mut request := thread_request.mir_serialize_thread_runtime_request(table, &ctx);
    mut witness := thread_request.mir_thread_runtime_mir_to_c_witness(table, &ctx);
    if os.WriteFile("/tmp/gust-phase17-thread-runtime.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase17-thread-runtime.mir-to-c.witness", witness) == 0 { os.Exit(6); }

    // Rejection: a pthread dependency with no permitted system import backing it.
    mut undeclared_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    undeclared_table = runtime.mir_runtime_table_with_abi(undeclared_table, abi, &ctx);
    undeclared_table = runtime.mir_runtime_table_with_component(undeclared_table, component, &ctx);
    undeclared_table = runtime.mir_runtime_table_with_package(undeclared_table, package, &ctx);
    undeclared_table = runtime.mir_runtime_table_with_package_member(undeclared_table, member, &ctx);
    undeclared_table = thread_with(undeclared_table, abi, component, package, "std_Mutex_Alloc", "mutex_create", "pthread", "caller_scoped", "no_cancellation_supported", "returns_explicit_error", 0, &ctx);
    mut undeclared_validation := runtime.mir_runtime_boundary_authority_table_validate(undeclared_table, &ctx);
    if undeclared_validation.valid == 1 || std.str_eq(undeclared_validation.reason_code, "runtime_thread_undeclared_system_library") == 0 { os.Exit(7); }

    // Rejection: a cancellation policy this patch does not claim.
    mut cancel_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    cancel_table = runtime.mir_runtime_table_with_abi(cancel_table, abi, &ctx);
    cancel_table = runtime.mir_runtime_table_with_component(cancel_table, component, &ctx);
    cancel_table = runtime.mir_runtime_table_with_package(cancel_table, package, &ctx);
    cancel_table = runtime.mir_runtime_table_with_package_member(cancel_table, member, &ctx);
    cancel_table = thread_with(cancel_table, abi, component, package, "std_Channel_Send_impl", "channel_send", "none", "caller_scoped", "async_cancellation", "total_cannot_fail", 0, &ctx);
    mut cancel_validation := runtime.mir_runtime_boundary_authority_table_validate(cancel_table, &ctx);
    if cancel_validation.valid == 1 || std.str_eq(cancel_validation.reason_code, "runtime_thread_unsupported_cancellation") == 0 { os.Exit(8); }

    // Rejection: an operation outside the bounded inventory.
    mut op_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    op_table = runtime.mir_runtime_table_with_abi(op_table, abi, &ctx);
    op_table = runtime.mir_runtime_table_with_component(op_table, component, &ctx);
    op_table = runtime.mir_runtime_table_with_package(op_table, package, &ctx);
    op_table = runtime.mir_runtime_table_with_package_member(op_table, member, &ctx);
    op_table = thread_with(op_table, abi, component, package, "std_Atomic_Fetch_Add", "atomic_fetch_add", "none", "caller_scoped", "no_cancellation_supported", "total_cannot_fail", 0, &ctx);
    mut op_validation := runtime.mir_runtime_boundary_authority_table_validate(op_table, &ctx);
    if op_validation.valid == 1 || std.str_eq(op_validation.reason_code, "runtime_thread_unsupported_target") == 0 { os.Exit(9); }

    os.LogStr("SUCCESS: Phase 17.12 threading synchronization smoke passed");
}
