// Phase 18.7 native smoke: linker discovery and invocation policy.
//
// Discovery is ordered and deterministic. The CC environment variable remains
// available but as a validated step in that order, never as an unvalidated
// escape hatch. Phase 18 plans the invocation; Phase 9G executes it.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func descriptor(result: str, supported_format: str, owner: str, argument: str, ctx: &Arena) target.MirLinkerDescriptor[ctx] {
    mut value: target.MirLinkerDescriptor[ctx];
    value.linker_id = std.Clone(ctx, "linker:v1:x86_64-unknown-linux-gnu");
    value.target_id = std.Clone(ctx, "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8");
    value.driver_name = std.Clone(ctx, "cc");
    value.discovery_result = std.Clone(ctx, result);
    value.supported_object_format = std.Clone(ctx, supported_format);
    value.invocation_owner = std.Clone(ctx, owner);
    value.probe_argument = std.Clone(ctx, argument);
    return value;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut good := descriptor("discovered", "elf", "phase9g_artifact_planner", "-o", &ctx);
    mut validation := target.mir_linker_descriptor_validate(good, "elf", &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    mut request := target_request.mir_serialize_linker_request(good, "elf", &ctx);
    mut witness := target_request.mir_linker_mir_to_c_witness(good, "elf", &ctx);
    if os.WriteFile("/tmp/gust-phase18-linker.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-linker.mir-to-c.witness", witness) == 0 { os.Exit(2); }

    // Rejection: a linker that does not support the target's object format.
    mut wrong_format := descriptor("discovered", "macho", "phase9g_artifact_planner", "-o", &ctx);
    mut wrong_validation := target.mir_linker_descriptor_validate(wrong_format, "elf", &ctx);
    if wrong_validation.valid == 1 || std.str_eq(wrong_validation.reason_code, "linker_unsupported_object_format") == 0 { os.Exit(3); }

    // Rejection: Phase 18 claiming to invoke the linker itself.
    mut self_invoked := descriptor("discovered", "elf", "phase18_target_authority", "-o", &ctx);
    mut self_validation := target.mir_linker_descriptor_validate(self_invoked, "elf", &ctx);
    if self_validation.valid == 1 || std.str_eq(self_validation.reason_code, "linker_invoked_by_phase18") == 0 { os.Exit(4); }

    // Rejection: an argument outside the declared vocabulary.
    mut bad_argument := descriptor("discovered", "elf", "phase9g_artifact_planner", "--wl,-rpath", &ctx);
    mut argument_validation := target.mir_linker_descriptor_validate(bad_argument, "elf", &ctx);
    if argument_validation.valid == 1 || std.str_eq(argument_validation.reason_code, "linker_argument_outside_vocabulary") == 0 { os.Exit(5); }

    // Rejection: an undiscovered linker cannot be used, only reported.
    mut undiscovered := descriptor("undiscovered_no_cross_linker_declared", "elf", "phase9g_artifact_planner", "-o", &ctx);
    mut undiscovered_validation := target.mir_linker_descriptor_validate(undiscovered, "elf", &ctx);
    if undiscovered_validation.valid == 1 || std.str_eq(undiscovered_validation.reason_code, "linker_undiscovered") == 0 { os.Exit(6); }

    os.LogStr("SUCCESS: Phase 18.7 linker policy smoke passed");
}
