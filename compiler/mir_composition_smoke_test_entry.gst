// Phase 17.14 native smoke: cross-feature runtime composition.
//
// Eight nested combinations, each naming the migrated authorities it exercises
// together. The load-bearing rule is coverage: every Phase 17 authority that
// migrated rows takes part in at least one case, so no capability is proven in
// isolation and then never composed. The inventory is derived from registry
// ownership rather than hand-maintained.

import "mir_runtime_boundary_authority.gst" as runtime;
import "mir_composition_request.gst" as composition_request;

func composition_target_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func compose(
    table: runtime.MirRuntimeBoundaryAuthorityTable[ctx],
    composition_kind: str,
    first: str,
    second: str,
    third: str,
    differential_owner: str,
    sentinel_policy: str,
    ordinal: int,
    ctx: &Arena
) runtime.MirRuntimeBoundaryAuthorityTable[ctx] {
    mut participants := runtime.mir_runtime_empty_strings(ctx);
    mut values: std.Vector[str, ctx] := ctx[participants];
    if len(first) != 0 { values.Push(first); }
    if len(second) != 0 { values.Push(second); }
    if len(third) != 0 { values.Push(third); }
    ctx.Set(participants, values);

    mut composition: runtime.MirRuntimeCompositionCase[ctx];
    composition.case_id = runtime.mir_runtime_composition_case_id(composition_kind, composition_target_id(), ordinal, ctx);
    composition.composition_kind = composition_kind;
    composition.participating_authorities = participants;
    composition.differential_owner = differential_owner;
    composition.target_applicability = "all_declared_host_targets_from_phase14_target_authority";
    composition.sentinel_policy = sentinel_policy;
    composition.target_id = composition_target_id();
    return runtime.mir_runtime_table_with_composition_case(table, composition, ctx);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_id := composition_target_id();
    mut table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);

    table = compose(table, "allocation_then_string_formatting_and_output", "phase17_runtime_authority", "phase17_memory_runtime_authority", "phase17_io_runtime_authority", "compiler_memory_and_io_differential_owner", "case_cannot_fail_no_output_to_preserve", 0, &ctx);
    table = compose(table, "resource_bearing_aggregate_across_runtime_call", "phase17_runtime_requirement_authority", "phase17_io_runtime_authority", "phase17_runtime_package_authority", "compiler_requirement_and_resource_differential_owner", "sentinel_output_preserved_on_failure", 1, &ctx);
    table = compose(table, "directory_acquire_branch_early_return_cleanup", "phase17_io_runtime_authority", "phase17_retained_c_authority", "", "compiler_resource_cleanup_differential_owner", "sentinel_output_preserved_on_failure", 2, &ctx);
    table = compose(table, "gust_runtime_helper_calling_stable_import", "phase17_gust_runtime_authority", "phase17_runtime_import_authority", "phase17_runtime_symbol_authority", "compiler_gust_and_import_differential_owner", "case_cannot_fail_no_output_to_preserve", 3, &ctx);
    table = compose(table, "rust_and_retained_c_in_one_package", "phase17_rust_runtime_authority", "phase17_retained_c_authority", "phase17_runtime_package_authority", "compiler_package_composition_differential_owner", "sentinel_output_preserved_on_failure", 4, &ctx);
    table = compose(table, "thread_helper_using_resource_cleanup", "phase17_thread_runtime_authority", "phase17_io_runtime_authority", "", "compiler_threading_and_cleanup_differential_owner", "sentinel_output_preserved_on_failure", 5, &ctx);
    table = compose(table, "compatible_package_from_target_candidates", "phase17_runtime_package_authority", "phase17_availability_authority", "", "compiler_package_selection_differential_owner", "sentinel_output_preserved_on_failure", 6, &ctx);
    table = compose(table, "incompatible_version_preserving_sentinel", "phase17_availability_authority", "phase17_runtime_symbol_authority", "phase17_shim_elimination_authority", "compiler_availability_failure_differential_owner", "sentinel_output_preserved_on_failure", 7, &ctx);

    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    mut cases: std.Vector[runtime.MirRuntimeCompositionCase[ctx], ctx] := ctx[table.composition_cases];
    if len(cases) != 8 { os.Exit(2); }

    // Every migrated Phase 17 authority takes part in at least one composition.
    if runtime.mir_runtime_composition_covers(table, "phase17_runtime_authority", &ctx) == 0 { os.Exit(3); }
    if runtime.mir_runtime_composition_covers(table, "phase17_runtime_symbol_authority", &ctx) == 0 { os.Exit(4); }
    if runtime.mir_runtime_composition_covers(table, "phase17_runtime_requirement_authority", &ctx) == 0 { os.Exit(5); }
    if runtime.mir_runtime_composition_covers(table, "phase17_runtime_package_authority", &ctx) == 0 { os.Exit(6); }
    if runtime.mir_runtime_composition_covers(table, "phase17_runtime_import_authority", &ctx) == 0 { os.Exit(7); }
    if runtime.mir_runtime_composition_covers(table, "phase17_rust_runtime_authority", &ctx) == 0 { os.Exit(8); }
    if runtime.mir_runtime_composition_covers(table, "phase17_retained_c_authority", &ctx) == 0 { os.Exit(9); }
    if runtime.mir_runtime_composition_covers(table, "phase17_gust_runtime_authority", &ctx) == 0 { os.Exit(10); }
    if runtime.mir_runtime_composition_covers(table, "phase17_shim_elimination_authority", &ctx) == 0 { os.Exit(11); }
    if runtime.mir_runtime_composition_covers(table, "phase17_memory_runtime_authority", &ctx) == 0 { os.Exit(12); }
    if runtime.mir_runtime_composition_covers(table, "phase17_io_runtime_authority", &ctx) == 0 { os.Exit(13); }
    if runtime.mir_runtime_composition_covers(table, "phase17_thread_runtime_authority", &ctx) == 0 { os.Exit(14); }
    if runtime.mir_runtime_composition_covers(table, "phase17_availability_authority", &ctx) == 0 { os.Exit(15); }
    if runtime.mir_runtime_composition_covers(table, "phase17_not_an_authority", &ctx) == 1 { os.Exit(16); }

    mut request := composition_request.mir_serialize_composition_request(table, &ctx);
    mut witness := composition_request.mir_composition_mir_to_c_witness(table, &ctx);
    if os.WriteFile("/tmp/gust-phase17-composition.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase17-composition.mir-to-c.witness", witness) == 0 { os.Exit(17); }

    // Rejection: a partial inventory leaves some combination unproven.
    mut partial := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    partial = compose(partial, "allocation_then_string_formatting_and_output", "phase17_memory_runtime_authority", "phase17_io_runtime_authority", "", "owner", "case_cannot_fail_no_output_to_preserve", 0, &ctx);
    mut partial_validation := runtime.mir_runtime_boundary_authority_table_validate(partial, &ctx);
    if partial_validation.valid == 1 || std.str_eq(partial_validation.reason_code, "runtime_composition_incomplete_inventory") == 0 { os.Exit(18); }

    // Rejection: a composition of one is not a composition.
    mut single := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    single = compose(single, "allocation_then_string_formatting_and_output", "phase17_memory_runtime_authority", "", "", "owner", "case_cannot_fail_no_output_to_preserve", 0, &ctx);
    mut single_validation := runtime.mir_runtime_boundary_authority_table_validate(single, &ctx);
    if single_validation.valid == 1 || std.str_eq(single_validation.reason_code, "runtime_composition_not_composed") == 0 { os.Exit(19); }

    // Rejection: a case with no differential owner.
    mut unowned := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    unowned = compose(unowned, "allocation_then_string_formatting_and_output", "phase17_memory_runtime_authority", "phase17_io_runtime_authority", "", "", "case_cannot_fail_no_output_to_preserve", 0, &ctx);
    mut unowned_validation := runtime.mir_runtime_boundary_authority_table_validate(unowned, &ctx);
    if unowned_validation.valid == 1 || std.str_eq(unowned_validation.reason_code, "runtime_composition_no_differential_owner") == 0 { os.Exit(20); }

    // Rejection: a combination outside the required nested inventory.
    mut unknown := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    unknown = compose(unknown, "everything_at_once", "phase17_memory_runtime_authority", "phase17_io_runtime_authority", "", "owner", "case_cannot_fail_no_output_to_preserve", 0, &ctx);
    mut unknown_validation := runtime.mir_runtime_boundary_authority_table_validate(unknown, &ctx);
    if unknown_validation.valid == 1 || std.str_eq(unknown_validation.reason_code, "runtime_composition_unknown_kind") == 0 { os.Exit(21); }

    os.LogStr("SUCCESS: Phase 17.14 cross-feature composition smoke passed");
}
