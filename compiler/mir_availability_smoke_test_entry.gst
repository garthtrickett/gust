// Phase 17.13 native smoke: runtime availability, compatibility, and diagnostic
// enforcement.
//
// Two things are frozen: the eight-step decision order, and the stage each step
// must complete before. Nothing reaches the linker, a temporary link output, or
// an output replacement until every compatibility question has been asked.

import "mir_runtime_boundary_authority.gst" as runtime;
import "mir_availability_request.gst" as availability_request;

func availability_target_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func decide(
    table: runtime.MirRuntimeBoundaryAuthorityTable[ctx],
    validation_step: str,
    rejection_class: str,
    stage_boundary: str,
    order: int,
    ctx: &Arena
) runtime.MirRuntimeBoundaryAuthorityTable[ctx] {
    mut decision: runtime.MirRuntimeAvailabilityDecision[ctx];
    decision.decision_id = runtime.mir_runtime_availability_decision_id(validation_step, order, availability_target_id(), ctx);
    decision.decision_order = order;
    decision.validation_step = validation_step;
    decision.rejection_class = rejection_class;
    decision.stage_boundary = stage_boundary;
    decision.target_id = availability_target_id();
    return runtime.mir_runtime_table_with_availability_decision(table, decision, ctx);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_id := availability_target_id();
    mut table := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);

    table = decide(table, "package_manifest_format", "runtime_manifest_malformed", "before_worker_execution", 0, &ctx);
    table = decide(table, "runtime_abi_identity_and_version", "runtime_abi_incompatible", "before_worker_execution", 1, &ctx);
    table = decide(table, "target_identity", "runtime_wrong_target", "before_worker_execution", 2, &ctx);
    table = decide(table, "required_component_presence", "runtime_component_missing", "after_target_selection_before_linker_invocation", 3, &ctx);
    table = decide(table, "required_symbol_presence_and_version", "runtime_symbol_missing", "after_target_selection_before_linker_invocation", 4, &ctx);
    table = decide(table, "function_abi_layout_and_resource_compatibility", "runtime_symbol_version_incompatible", "after_target_selection_before_linker_invocation", 5, &ctx);
    table = decide(table, "declared_system_library_requirements", "runtime_link_plan_dependency_undeclared", "after_target_selection_before_linker_invocation", 6, &ctx);
    table = decide(table, "deterministic_component_and_link_ordering", "runtime_classification_inconsistent", "after_target_selection_before_linker_invocation", 7, &ctx);

    mut validation := runtime.mir_runtime_boundary_authority_table_validate(table, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    mut decisions: std.Vector[runtime.MirRuntimeAvailabilityDecision[ctx], ctx] := ctx[table.availability_decisions];
    if len(decisions) != 8 { os.Exit(2); }

    mut manifest_query := runtime.mir_runtime_availability_decision_for(table, "package_manifest_format", &ctx);
    if manifest_query.found == 0 || manifest_query.value.decision_order != 0 { os.Exit(3); }
    if std.str_eq(manifest_query.value.stage_boundary, "before_worker_execution") == 0 { os.Exit(4); }
    mut ordering_query := runtime.mir_runtime_availability_decision_for(table, "deterministic_component_and_link_ordering", &ctx);
    if ordering_query.found == 0 || ordering_query.value.decision_order != 7 { os.Exit(5); }
    mut absent := runtime.mir_runtime_availability_decision_for(table, "guess_and_hope", &ctx);
    if absent.found == 1 { os.Exit(6); }

    mut request := availability_request.mir_serialize_availability_request(table, &ctx);
    mut witness := availability_request.mir_availability_mir_to_c_witness(table, &ctx);
    if os.WriteFile("/tmp/gust-phase17-availability.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase17-availability.mir-to-c.witness", witness) == 0 { os.Exit(7); }

    // Rejection: a partial order means some compatibility question went unasked.
    mut partial := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    partial = decide(partial, "package_manifest_format", "runtime_manifest_malformed", "before_worker_execution", 0, &ctx);
    mut partial_validation := runtime.mir_runtime_boundary_authority_table_validate(partial, &ctx);
    if partial_validation.valid == 1 || std.str_eq(partial_validation.reason_code, "runtime_availability_incomplete_order") == 0 { os.Exit(8); }

    // Rejection: a reordered sequence is not the frozen order.
    mut reordered := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    reordered = decide(reordered, "target_identity", "runtime_wrong_target", "before_worker_execution", 3, &ctx);
    mut reordered_validation := runtime.mir_runtime_boundary_authority_table_validate(reordered, &ctx);
    if reordered_validation.valid == 1 || std.str_eq(reordered_validation.reason_code, "runtime_availability_decision_order_drift") == 0 { os.Exit(9); }

    // Rejection: a decision deferred past the point output could exist.
    mut late := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    late = decide(late, "package_manifest_format", "runtime_manifest_malformed", "during_output_replacement", 0, &ctx);
    mut late_validation := runtime.mir_runtime_boundary_authority_table_validate(late, &ctx);
    if late_validation.valid == 1 || std.str_eq(late_validation.reason_code, "runtime_availability_late_decision") == 0 { os.Exit(10); }

    // Rejection: a rejection class outside the stable inventory.
    mut unclassified := runtime.mir_runtime_make_empty_table(target_id, "x86_64-unknown-linux-gnu", &ctx);
    unclassified = decide(unclassified, "package_manifest_format", "something_went_wrong", "before_worker_execution", 0, &ctx);
    mut unclassified_validation := runtime.mir_runtime_boundary_authority_table_validate(unclassified, &ctx);
    if unclassified_validation.valid == 1 || std.str_eq(unclassified_validation.reason_code, "runtime_availability_unclassified_rejection") == 0 { os.Exit(11); }

    os.LogStr("SUCCESS: Phase 17.13 availability diagnostics smoke passed");
}
