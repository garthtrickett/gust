// Phase 18.2 native smoke: the complete target support tuple.
//
// Support is a conjunction. A tuple is complete only when all four elements are
// present, compatible, and evidenced, and every element names the authority
// that owns it. Both failure directions are rejections: claiming supported
// without a complete tuple, and claiming unsupported without saying what is
// absent.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func linux_x86_64_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func make_tuple(
    decision: str,
    compiler_ok: int,
    package_ok: int,
    linker_ok: int,
    abi_ok: int,
    named_missing: int,
    frozen: int,
    ctx: &Arena
) target.MirTargetSupportTuple[ctx] {
    mut tuple: target.MirTargetSupportTuple[ctx];
    tuple.tuple_id = std.Clone(ctx, "tuple:v1:x86_64-unknown-linux-gnu");
    tuple.target_id = std.Clone(ctx, linux_x86_64_id());
    tuple.compiler_element = target.mir_target_make_element("compiler", "phase18_target_authority", "evidence:compiler:1", compiler_ok, compiler_ok, ctx);
    tuple.runtime_package_element = target.mir_target_make_element("runtime_package", "phase17_runtime_package_authority", "evidence:package:1", package_ok, package_ok, ctx);
    tuple.linker_element = target.mir_target_make_element("linker", "pending_patch18_7_linker_policy", "evidence:linker:1", linker_ok, linker_ok, ctx);
    tuple.abi_element = target.mir_target_make_element("abi", "pending_patch18_5_target_abi_selection", "evidence:abi:1", abi_ok, abi_ok, ctx);
    tuple.support_decision = std.Clone(ctx, decision);
    mut missing: std.Vector[str, ctx] := std.VectorNew(ctx);
    if named_missing == 1 {
        if compiler_ok == 0 { missing.Push(std.Clone(ctx, "compiler")); }
        if package_ok == 0 { missing.Push(std.Clone(ctx, "runtime_package")); }
        if linker_ok == 0 { missing.Push(std.Clone(ctx, "linker")); }
        if abi_ok == 0 { missing.Push(std.Clone(ctx, "abi")); }
    }
    mut index: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, missing);
    tuple.missing_elements = index;
    tuple.validation_order_frozen = frozen;
    return tuple;
}


// AUDIT (18.18): two declared classes with no negative test. Both need a tuple
// shaped in ways make_tuple cannot produce, so they get their own builders.
func complete_tuple_with_stray_missing(ctx: &Arena) target.MirTargetSupportTuple[ctx] {
    mut tuple := make_tuple("supported", 1, 1, 1, 1, 0, 1, ctx);
    mut missing: std.Vector[str, ctx] := std.VectorNew(ctx);
    missing.Push(std.Clone(ctx, "linker"));
    mut index: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, missing);
    tuple.missing_elements = index;
    return tuple;
}

func tuple_with_unattributed_element(ctx: &Arena) target.MirTargetSupportTuple[ctx] {
    mut tuple := make_tuple("supported", 1, 1, 1, 1, 0, 1, ctx);
    tuple.linker_element = target.mir_target_make_element("linker", "", "", 1, 1, ctx);
    return tuple;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut table := target.mir_target_make_empty_table(&ctx);

    // Accepting case: every element supplied, decision supported, nothing missing.
    mut complete := make_tuple("supported", 1, 1, 1, 1, 0, 1, &ctx);
    mut complete_validation := target.mir_target_tuple_validate(complete, &ctx);
    if complete_validation.valid == 0 { os.LogStr(complete_validation.reason_code); os.Exit(1); }
    if target.mir_target_tuple_is_complete(complete, &ctx) == 0 { os.Exit(2); }

    // Accepting case: the Patch 18.2 reality, where only the compiler element
    // exists and the tuple says exactly which three are absent.
    mut pending := make_tuple("unsupported_pending_tuple_evidence", 1, 0, 0, 0, 1, 1, &ctx);
    mut pending_validation := target.mir_target_tuple_validate(pending, &ctx);
    if pending_validation.valid == 0 { os.LogStr(pending_validation.reason_code); os.Exit(3); }
    if target.mir_target_tuple_is_complete(pending, &ctx) == 1 { os.Exit(4); }

    mut request := target_request.mir_serialize_target_support_request(table, pending, &ctx);
    mut witness := target_request.mir_target_support_mir_to_c_witness(table, pending, &ctx);
    if os.WriteFile("/tmp/gust-phase18-support.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-support.mir-to-c.witness", witness) == 0 { os.Exit(5); }

    // Rejection: supported without a complete tuple.
    mut overclaimed := make_tuple("supported", 1, 0, 0, 0, 0, 1, &ctx);
    mut overclaimed_validation := target.mir_target_tuple_validate(overclaimed, &ctx);
    if overclaimed_validation.valid == 1 || std.str_eq(overclaimed_validation.reason_code, "target_supported_without_complete_tuple") == 0 { os.Exit(6); }

    // Rejection: unsupported without naming what is absent.
    mut silent := make_tuple("unsupported_missing_elements", 1, 0, 0, 0, 0, 1, &ctx);
    mut silent_validation := target.mir_target_tuple_validate(silent, &ctx);
    if silent_validation.valid == 1 || std.str_eq(silent_validation.reason_code, "target_unsupported_without_named_missing_elements") == 0 { os.Exit(7); }

    // Rejection: a complete tuple recorded as unsupported. The decision, not the
    // missing list, is what drifted here.
    mut understated := make_tuple("unsupported_missing_elements", 1, 1, 1, 1, 1, 1, &ctx);
    mut understated_validation := target.mir_target_tuple_validate(understated, &ctx);
    if understated_validation.valid == 1 || std.str_eq(understated_validation.reason_code, "target_support_decision_drift") == 0 { os.Exit(8); }

    // Rejection: an unfrozen validation order.
    mut unfrozen := make_tuple("unsupported_pending_tuple_evidence", 1, 0, 0, 0, 1, 0, &ctx);
    mut unfrozen_validation := target.mir_target_tuple_validate(unfrozen, &ctx);
    if unfrozen_validation.valid == 1 || std.str_eq(unfrozen_validation.reason_code, "target_support_order_not_frozen") == 0 { os.Exit(9); }


    // AUDIT (18.18): a complete tuple that still names a missing element. The
    // two statements contradict each other, so the tuple cannot be trusted.
    mut strayed := target.mir_target_tuple_validate(complete_tuple_with_stray_missing(&ctx), &ctx);
    if strayed.valid == 1 || std.str_eq(strayed.reason_code, "target_support_missing_elements_drift") == 0 { os.Exit(20); }

    // AUDIT (18.18): an element naming no owning authority and no evidence.
    // Completeness judges present and compatible only, so without this the
    // tuple could list all four parts and prove none of them.
    mut unattributed := target.mir_target_tuple_validate(tuple_with_unattributed_element(&ctx), &ctx);
    if unattributed.valid == 1 || std.str_eq(unattributed.reason_code, "target_support_element_without_owner_or_evidence") == 0 { os.Exit(21); }

    os.LogStr("SUCCESS: Phase 18.2 target support tuple smoke passed");
}
