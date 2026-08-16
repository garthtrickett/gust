import "mir_runtime_boundary_authority.gst" as runtime;
import "mir_native_backend_runtime_request.gst" as runtime_request;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_id := "target:x86_64-unknown-linux-gnu";
    mut table := runtime.mir_runtime_make_empty_table(
        target_id,
        "x86_64-unknown-linux-gnu",
        &ctx
    );

    mut abi: runtime.MirRuntimeAbiIdentity[ctx];
    abi.runtime_abi_id = runtime.mir_runtime_abi_identity_id("module:smoke", target_id, 0, &ctx);
    abi.abi_version = "runtime-abi-v1";
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

    mut helper: runtime.MirRuntimeHelperIdentity[ctx];
    helper.helper_id = runtime.mir_runtime_helper_identity_id("arena_new", target_id, 0, &ctx);
    helper.operation_id = "arena_new";
    helper.symbol_identity = "os_Arena_New";
    helper.source_location = "src/runtime/arena.c:28";
    helper.target_applicability = "all_declared_host_targets_from_phase14_target_authority";
    table = runtime.mir_runtime_table_with_helper(table, helper, &ctx);

    mut classification: runtime.MirRuntimeHelperClassification[ctx];
    classification.classification_id = runtime.mir_runtime_classification_id(helper.helper_id, 0, &ctx);
    classification.helper_id = helper.helper_id;
    classification.classification = "retained_c_runtime_component";
    classification.component_id = component.component_id;
    classification.reason_code = "runtime_helper_classified_retained_c";
    table = runtime.mir_runtime_table_with_classification(table, classification, &ctx);

    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, &ctx);
    if validation.valid == 0 { os.Exit(1); }
    mut helper_query := runtime.mir_runtime_helper_of(table, "arena_new", &ctx);
    if helper_query.found == 0 { os.Exit(2); }
    mut classification_query := runtime.mir_classify_runtime_helper(table, helper.helper_id, &ctx);
    if classification_query.found == 0 || std.str_eq(classification_query.value.classification, "retained_c_runtime_component") == 0 { os.Exit(3); }

    // Keep the request module in the generic producer graph without requiring
    // a native driver, worker, object, linker, or output artifact in Level 1.
    if std.str_eq("runtime_request", "runtime_request") == 0 { os.Exit(4); }
    os.LogStr("SUCCESS: Phase 17.1 runtime boundary authority smoke passed");
}
