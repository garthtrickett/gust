// Phase 18.10 native smoke: unsupported-target detection and diagnostics.
//
// An unsupported target names the tuple elements it actually lacks and is
// refused before driver discovery. A refusal that does not say what is missing
// is not a diagnostic, and a supported target carries no rejection class.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func diagnostic(decision: str, missing: str, rejection: str, stage: str, ctx: &Arena) target.MirTargetDiagnostic[ctx] {
    mut value: target.MirTargetDiagnostic[ctx];
    value.target_id = std.Clone(ctx, "target:v1:triple=aarch64-apple-darwin:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8");
    value.support_decision = std.Clone(ctx, decision);
    value.missing_element = std.Clone(ctx, missing);
    value.rejection_class = std.Clone(ctx, rejection);
    value.failure_stage = std.Clone(ctx, stage);
    return value;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    // Accepting: an unsupported target naming its missing element and class.
    mut unsupported := diagnostic("unsupported_missing_elements", "linker", "missing_linker", "before_driver_discovery", &ctx);
    mut validation := target.mir_target_diagnostic_validate(unsupported, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    // Accepting: a supported target with no missing element and no class.
    mut supported := diagnostic("supported", "", "", "before_driver_discovery", &ctx);
    mut supported_validation := target.mir_target_diagnostic_validate(supported, &ctx);
    if supported_validation.valid == 0 { os.LogStr(supported_validation.reason_code); os.Exit(2); }

    mut request := target_request.mir_serialize_target_diagnostic_request(unsupported, &ctx);
    mut witness := target_request.mir_target_diagnostic_mir_to_c_witness(unsupported, &ctx);
    if os.WriteFile("/tmp/gust-phase18-diag.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-diag.mir-to-c.witness", witness) == 0 { os.Exit(3); }

    // Rejection: unsupported without naming a rejection class.
    mut vague := diagnostic("unsupported_missing_elements", "linker", "", "before_driver_discovery", &ctx);
    mut vague_validation := target.mir_target_diagnostic_validate(vague, &ctx);
    if vague_validation.valid == 1 || std.str_eq(vague_validation.reason_code, "target_diagnostic_generic_refusal") == 0 { os.Exit(4); }

    // Rejection: unsupported without naming a missing element.
    mut unnamed := diagnostic("unsupported_missing_elements", "", "missing_linker", "before_driver_discovery", &ctx);
    mut unnamed_validation := target.mir_target_diagnostic_validate(unnamed, &ctx);
    if unnamed_validation.valid == 1 || std.str_eq(unnamed_validation.reason_code, "target_diagnostic_generic_refusal") == 0 { os.Exit(5); }

    // Rejection: a supported target carrying a rejection class.
    mut contradictory := diagnostic("supported", "", "missing_linker", "before_driver_discovery", &ctx);
    mut contradictory_validation := target.mir_target_diagnostic_validate(contradictory, &ctx);
    if contradictory_validation.valid == 1 || std.str_eq(contradictory_validation.reason_code, "target_diagnostic_supported_with_rejection") == 0 { os.Exit(6); }

    // Rejection: a refusal deferred past the point output could exist.
    mut late := diagnostic("unsupported_missing_elements", "linker", "missing_linker", "during_output_replacement", &ctx);
    mut late_validation := target.mir_target_diagnostic_validate(late, &ctx);
    if late_validation.valid == 1 || std.str_eq(late_validation.reason_code, "target_diagnostic_refused_too_late") == 0 { os.Exit(7); }

    os.LogStr("SUCCESS: Phase 18.10 target diagnostics smoke passed");
}
