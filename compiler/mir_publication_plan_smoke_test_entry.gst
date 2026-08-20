// Phase 18.16 native smoke: atomic executable publication.
//
// Publication is the last step that can destroy a valid artifact, so its
// position in the order is the whole contract. Every validation precedes it,
// the replacement is atomic, and Phase 9G executes what Phase 18 plans.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func plan(after_emission: int, after_relocation: int, after_availability: int, after_link: int, atomic: int, executor: str, ctx: &Arena) target.MirPublicationPlan[ctx] {
    mut value: target.MirPublicationPlan[ctx];
    value.target_id = std.Clone(ctx, "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8");
    value.after_object_emission = after_emission;
    value.after_relocation_validation = after_relocation;
    value.after_availability_validation = after_availability;
    value.after_link_success = after_link;
    value.atomic = atomic;
    value.executor = std.Clone(ctx, executor);
    return value;
}


// Built in a helper: `target.MirTemporaryArtifact[ctx]` needs the [ctx] generic
// parameter that func main() does not carry.
func temporary(artifact: str, owner: str, cleanup_rule: str, ctx: &Arena) target.MirTemporaryArtifact[ctx] {
    mut value: target.MirTemporaryArtifact[ctx];
    value.artifact = std.Clone(ctx, artifact);
    value.owner = std.Clone(ctx, owner);
    value.cleanup_rule = std.Clone(ctx, cleanup_rule);
    return value;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut good := plan(1, 1, 1, 1, 1, "phase9g_artifact_planner", &ctx);
    mut validation := target.mir_publication_plan_validate(good, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    mut request := target_request.mir_serialize_publication_request(good, &ctx);
    mut witness := target_request.mir_publication_mir_to_c_witness(good, &ctx);
    if os.WriteFile("/tmp/gust-phase18-publish.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-publish.mir-to-c.witness", witness) == 0 { os.Exit(2); }

    // Rejection: publishing before the object exists.
    mut early_object := plan(0, 1, 1, 1, 1, "phase9g_artifact_planner", &ctx);
    mut early_object_validation := target.mir_publication_plan_validate(early_object, &ctx);
    if early_object_validation.valid == 1 || std.str_eq(early_object_validation.reason_code, "publication_before_object_emission") == 0 { os.Exit(3); }

    // Rejection: publishing before relocations were validated.
    mut early_reloc := plan(1, 0, 1, 1, 1, "phase9g_artifact_planner", &ctx);
    mut early_reloc_validation := target.mir_publication_plan_validate(early_reloc, &ctx);
    if early_reloc_validation.valid == 1 || std.str_eq(early_reloc_validation.reason_code, "publication_before_relocation_validation") == 0 { os.Exit(4); }

    // Rejection: publishing before the link succeeded.
    mut early_link := plan(1, 1, 1, 0, 1, "phase9g_artifact_planner", &ctx);
    mut early_link_validation := target.mir_publication_plan_validate(early_link, &ctx);
    if early_link_validation.valid == 1 || std.str_eq(early_link_validation.reason_code, "publication_before_link_success") == 0 { os.Exit(5); }

    // Rejection: a non-atomic replacement can leave a partial executable.
    mut non_atomic := plan(1, 1, 1, 1, 0, "phase9g_artifact_planner", &ctx);
    mut non_atomic_validation := target.mir_publication_plan_validate(non_atomic, &ctx);
    if non_atomic_validation.valid == 1 || std.str_eq(non_atomic_validation.reason_code, "publication_not_atomic") == 0 { os.Exit(6); }

    // Rejection: Phase 18 executing rather than planning.
    mut self_executed := plan(1, 1, 1, 1, 1, "phase18_target_authority", &ctx);
    mut self_validation := target.mir_publication_plan_validate(self_executed, &ctx);
    if self_validation.valid == 1 || std.str_eq(self_validation.reason_code, "publication_executed_by_phase18") == 0 { os.Exit(7); }


    // Rejection: publication planned before the availability check that proves
    // the target's complete support tuple is actually present.
    mut early := plan(1, 1, 0, 1, 1, "phase9g_artifact_planner", &ctx);
    mut early_validation := target.mir_publication_plan_validate(early, &ctx);
    if early_validation.valid == 1 || std.str_eq(early_validation.reason_code, "publication_before_availability_validation") == 0 { os.Exit(11); }

    // Rejection: a temporary artifact naming no owner and no cleanup rule. This
    // is the record that, left unowned, leaves half-written objects behind after
    // a failed build.
    mut orphan_validation := target.mir_temporary_artifact_validate(temporary("program_object", "", "", &ctx), &ctx);
    if orphan_validation.valid == 1 || std.str_eq(orphan_validation.reason_code, "temporary_artifact_without_owner_or_cleanup_rule") == 0 { os.Exit(12); }

    // Rejection: Phase 18 naming itself as the owner that performs the cleanup.
    mut self_owned := target.mir_temporary_artifact_validate(temporary("program_object", "phase18", "removed_after_link_success_or_failure", &ctx), &ctx);
    if self_owned.valid == 1 || std.str_eq(self_owned.reason_code, "publication_executed_by_phase18") == 0 { os.Exit(13); }

    // Sentinel: the same artifact owned by Phase 9G with a rule is accepted.
    if target.mir_temporary_artifact_validate(temporary("program_object", "phase9g_artifact_planner", "removed_after_link_success_or_failure", &ctx), &ctx).valid == 0 { os.Exit(14); }

    os.LogStr("SUCCESS: Phase 18.16 publication smoke passed");
}
