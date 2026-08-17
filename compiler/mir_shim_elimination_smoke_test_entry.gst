// Phase 17.9 native smoke: generated C shim elimination and obsolete helper
// removal. Every banned wrapper class is paired with the compiler-owned thing
// that replaced it, and the evidence policy is that explicit Cranelift succeeds
// with the C compiler unavailable.

import "mir_runtime_boundary_authority.gst" as runtime;
import "mir_shim_elimination_request.gst" as shim_request;

func shim_target_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_id := shim_target_id();
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

    mut ban0: runtime.MirRuntimeShimBan[ctx];
    ban0.ban_id = runtime.mir_runtime_shim_ban_id("runtime_call_wrapper", target_id, 0, &ctx);
    ban0.banned_class = "runtime_call_wrapper";
    ban0.obsolete_family = "*_IsValid";
    ban0.replacement_kind = "compiler_owned_direct_import";
    ban0.replacement_component_id = component.component_id;
    ban0.target_id = target_id;
    ban0.evidence_policy = "explicit_cranelift_succeeds_with_c_compiler_unavailable";
    table = runtime.mir_runtime_table_with_shim_ban(table, ban0, &ctx);

    mut ban1: runtime.MirRuntimeShimBan[ctx];
    ban1.ban_id = runtime.mir_runtime_shim_ban_id("abi_adaptation_wrapper", target_id, 1, &ctx);
    ban1.banned_class = "abi_adaptation_wrapper";
    ban1.obsolete_family = "std_GenerationalArena_Clone_*";
    ban1.replacement_kind = "explicit_runtime_component";
    ban1.replacement_component_id = component.component_id;
    ban1.target_id = target_id;
    ban1.evidence_policy = "explicit_cranelift_succeeds_with_c_compiler_unavailable";
    table = runtime.mir_runtime_table_with_shim_ban(table, ban1, &ctx);

    mut ban2: runtime.MirRuntimeShimBan[ctx];
    ban2.ban_id = runtime.mir_runtime_shim_ban_id("resource_or_cleanup_wrapper", target_id, 2, &ctx);
    ban2.banned_class = "resource_or_cleanup_wrapper";
    ban2.obsolete_family = "std_GenerationalArena_Clone_*";
    ban2.replacement_kind = "explicit_runtime_component";
    ban2.replacement_component_id = component.component_id;
    ban2.target_id = target_id;
    ban2.evidence_policy = "explicit_cranelift_succeeds_with_c_compiler_unavailable";
    table = runtime.mir_runtime_table_with_shim_ban(table, ban2, &ctx);

    mut ban3: runtime.MirRuntimeShimBan[ctx];
    ban3.ban_id = runtime.mir_runtime_shim_ban_id("allocation_or_string_helper_wrapper", target_id, 3, &ctx);
    ban3.banned_class = "allocation_or_string_helper_wrapper";
    ban3.obsolete_family = "*_IsValid";
    ban3.replacement_kind = "explicit_runtime_component";
    ban3.replacement_component_id = component.component_id;
    ban3.target_id = target_id;
    ban3.evidence_policy = "explicit_cranelift_succeeds_with_c_compiler_unavailable";
    table = runtime.mir_runtime_table_with_shim_ban(table, ban3, &ctx);

    mut ban4: runtime.MirRuntimeShimBan[ctx];
    ban4.ban_id = runtime.mir_runtime_shim_ban_id("io_filesystem_or_threading_wrapper", target_id, 4, &ctx);
    ban4.banned_class = "io_filesystem_or_threading_wrapper";
    ban4.obsolete_family = "*_pthread_wrapper";
    ban4.replacement_kind = "explicit_runtime_component";
    ban4.replacement_component_id = component.component_id;
    ban4.target_id = target_id;
    ban4.evidence_policy = "explicit_cranelift_succeeds_with_c_compiler_unavailable";
    table = runtime.mir_runtime_table_with_shim_ban(table, ban4, &ctx);

    mut ban5: runtime.MirRuntimeShimBan[ctx];
    ban5.ban_id = runtime.mir_runtime_shim_ban_id("target_selection_wrapper_fragment", target_id, 5, &ctx);
    ban5.banned_class = "target_selection_wrapper_fragment";
    ban5.obsolete_family = "gust_user_main/main";
    ban5.replacement_kind = "narrower_explicit_deferral";
    ban5.replacement_component_id = "";
    ban5.target_id = target_id;
    ban5.evidence_policy = "explicit_cranelift_succeeds_with_c_compiler_unavailable";
    table = runtime.mir_runtime_table_with_shim_ban(table, ban5, &ctx);

    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    // All six wrapper classes the patch removes are covered.
    mut covered := 0;
    if runtime.mir_runtime_shim_ban_for(table, "runtime_call_wrapper", &ctx).found == 1 { covered = covered + 1; }
    if runtime.mir_runtime_shim_ban_for(table, "abi_adaptation_wrapper", &ctx).found == 1 { covered = covered + 1; }
    if runtime.mir_runtime_shim_ban_for(table, "resource_or_cleanup_wrapper", &ctx).found == 1 { covered = covered + 1; }
    if runtime.mir_runtime_shim_ban_for(table, "allocation_or_string_helper_wrapper", &ctx).found == 1 { covered = covered + 1; }
    if runtime.mir_runtime_shim_ban_for(table, "io_filesystem_or_threading_wrapper", &ctx).found == 1 { covered = covered + 1; }
    if runtime.mir_runtime_shim_ban_for(table, "target_selection_wrapper_fragment", &ctx).found == 1 { covered = covered + 1; }
    if covered != 6 { os.Exit(2); }
    if runtime.mir_runtime_shim_ban_for(table, "not_a_banned_class", &ctx).found == 1 { os.Exit(3); }

    mut request := shim_request.mir_serialize_shim_elimination_request(table, &ctx);
    mut witness := shim_request.mir_shim_elimination_mir_to_c_witness(table, &ctx);
    if os.WriteFile("/tmp/gust-phase17-shim-elimination.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase17-shim-elimination.mir-to-c.witness", witness) == 0 { os.Exit(4); }
    if std.str_find(witness, "linkage=native_path_emits_no_program_specific_c") == 0 - 1 { os.Exit(5); }

    // Rejection: a wrapper class outside the removed inventory.
    mut unknown := ban0;
    unknown.ban_id = runtime.mir_runtime_shim_ban_id("mystery_wrapper", target_id, 9, &ctx);
    unknown.banned_class = "mystery_wrapper";
    mut unknown_validation := runtime.mir_runtime_boundary_authority_table_validate(
        runtime.mir_runtime_table_with_shim_ban(table, unknown, &ctx), &ctx);
    if unknown_validation.valid == 1 || std.str_eq(unknown_validation.reason_code, "runtime_shim_unclassified_ban") == 0 { os.Exit(6); }

    // Rejection: a ban with no compiler-owned replacement behind it.
    mut unbacked := ban0;
    unbacked.ban_id = runtime.mir_runtime_shim_ban_id("runtime_call_wrapper", target_id, 10, &ctx);
    unbacked.banned_class = "runtime_call_wrapper";
    unbacked.replacement_kind = "just_removed_it";
    mut unbacked_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    unbacked_table = runtime.mir_runtime_table_with_abi(unbacked_table, abi, &ctx);
    unbacked_table = runtime.mir_runtime_table_with_component(unbacked_table, component, &ctx);
    unbacked_table = runtime.mir_runtime_table_with_shim_ban(unbacked_table, unbacked, &ctx);
    mut unbacked_validation := runtime.mir_runtime_boundary_authority_table_validate(unbacked_table, &ctx);
    if unbacked_validation.valid == 1 || std.str_eq(unbacked_validation.reason_code, "runtime_shim_ban_without_replacement") == 0 { os.Exit(7); }

    // Rejection: a replacement naming a component the table never declared.
    mut fictional := ban0;
    fictional.ban_id = runtime.mir_runtime_shim_ban_id("runtime_call_wrapper", target_id, 11, &ctx);
    fictional.replacement_component_id = "runtime_component:does_not_exist";
    mut fictional_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    fictional_table = runtime.mir_runtime_table_with_abi(fictional_table, abi, &ctx);
    fictional_table = runtime.mir_runtime_table_with_component(fictional_table, component, &ctx);
    fictional_table = runtime.mir_runtime_table_with_shim_ban(fictional_table, fictional, &ctx);
    mut fictional_validation := runtime.mir_runtime_boundary_authority_table_validate(fictional_table, &ctx);
    if fictional_validation.valid == 1 || std.str_eq(fictional_validation.reason_code, "runtime_shim_ban_without_replacement") == 0 { os.Exit(8); }

    // Rejection: a ban that does not carry the cc-unavailable evidence policy.
    mut unevidenced := ban0;
    unevidenced.ban_id = runtime.mir_runtime_shim_ban_id("runtime_call_wrapper", target_id, 12, &ctx);
    unevidenced.evidence_policy = "trust_me";
    mut unevidenced_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    unevidenced_table = runtime.mir_runtime_table_with_abi(unevidenced_table, abi, &ctx);
    unevidenced_table = runtime.mir_runtime_table_with_component(unevidenced_table, component, &ctx);
    unevidenced_table = runtime.mir_runtime_table_with_shim_ban(unevidenced_table, unevidenced, &ctx);
    mut unevidenced_validation := runtime.mir_runtime_boundary_authority_table_validate(unevidenced_table, &ctx);
    if unevidenced_validation.valid == 1 || std.str_eq(unevidenced_validation.reason_code, "runtime_shim_missing_evidence") == 0 { os.Exit(9); }

    // Rejection: the same wrapper class banned twice.
    mut duplicate := ban0;
    duplicate.ban_id = runtime.mir_runtime_shim_ban_id("runtime_call_wrapper", target_id, 13, &ctx);
    mut duplicate_table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    duplicate_table = runtime.mir_runtime_table_with_abi(duplicate_table, abi, &ctx);
    duplicate_table = runtime.mir_runtime_table_with_component(duplicate_table, component, &ctx);
    duplicate_table = runtime.mir_runtime_table_with_shim_ban(duplicate_table, ban0, &ctx);
    duplicate_table = runtime.mir_runtime_table_with_shim_ban(duplicate_table, duplicate, &ctx);
    mut duplicate_validation := runtime.mir_runtime_boundary_authority_table_validate(duplicate_table, &ctx);
    if duplicate_validation.valid == 1 || std.str_eq(duplicate_validation.reason_code, "runtime_shim_duplicate_ban") == 0 { os.Exit(10); }

    os.LogStr("SUCCESS: Phase 17.9 shim elimination smoke passed");
}
