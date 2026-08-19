// Phase 18.9 native smoke: cross-compilation policy and host/target separation.
//
// A pair is cross exactly when the target triple differs from the host triple,
// and a cross pair may be declared only when its linker was discovered.
// Declaring a pair that cannot link would be a claim without evidence.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func pair(host: str, target_triple: str, linker_found: int, declared: int, blocking: str, ctx: &Arena) target.MirHostTargetPair[ctx] {
    mut value: target.MirHostTargetPair[ctx];
    value.host_triple = std.Clone(ctx, host);
    value.target_triple = std.Clone(ctx, target_triple);
    value.linker_discovered = linker_found;
    value.declared = declared;
    value.blocking_reason = std.Clone(ctx, blocking);
    return value;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut host := "x86_64-unknown-linux-gnu";

    if std.str_eq(target.mir_cross_classification(host, host, &ctx), "native") == 0 { os.Exit(1); }
    if std.str_eq(target.mir_cross_classification(host, "aarch64-apple-darwin", &ctx), "cross") == 0 { os.Exit(2); }

    // Accepting: the native pair, undeclared as cross and needing no blocker.
    mut native := pair(host, host, 1, 0, "", &ctx);
    mut native_validation := target.mir_host_target_pair_validate(native, &ctx);
    if native_validation.valid == 0 { os.LogStr(native_validation.reason_code); os.Exit(3); }

    // Accepting: a cross candidate blocked by a missing linker.
    mut blocked := pair(host, "aarch64-apple-darwin", 0, 0, "no_declared_cross_linker_for_this_target", &ctx);
    mut blocked_validation := target.mir_host_target_pair_validate(blocked, &ctx);
    if blocked_validation.valid == 0 { os.LogStr(blocked_validation.reason_code); os.Exit(4); }

    mut request := target_request.mir_serialize_cross_pair_request(blocked, &ctx);
    mut witness := target_request.mir_cross_pair_mir_to_c_witness(blocked, &ctx);
    if os.WriteFile("/tmp/gust-phase18-cross.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-cross.mir-to-c.witness", witness) == 0 { os.Exit(5); }

    // Rejection: a cross pair declared without a discovered linker.
    mut unfounded := pair(host, "aarch64-apple-darwin", 0, 1, "", &ctx);
    mut unfounded_validation := target.mir_host_target_pair_validate(unfounded, &ctx);
    if unfounded_validation.valid == 1 || std.str_eq(unfounded_validation.reason_code, "cross_pair_incomplete_tuple") == 0 { os.Exit(6); }

    // Rejection: an undeclared cross pair that states no blocker.
    mut silent := pair(host, "aarch64-apple-darwin", 0, 0, "", &ctx);
    mut silent_validation := target.mir_host_target_pair_validate(silent, &ctx);
    if silent_validation.valid == 1 || std.str_eq(silent_validation.reason_code, "cross_pair_undeclared") == 0 { os.Exit(7); }

    // Rejection: a declared pair that also carries a blocking reason.
    mut contradictory := pair(host, "aarch64-apple-darwin", 1, 1, "no_declared_cross_linker_for_this_target", &ctx);
    mut contradictory_validation := target.mir_host_target_pair_validate(contradictory, &ctx);
    if contradictory_validation.valid == 1 || std.str_eq(contradictory_validation.reason_code, "cross_pair_undeclared") == 0 { os.Exit(8); }

    os.LogStr("SUCCESS: Phase 18.9 cross compilation smoke passed");
}
