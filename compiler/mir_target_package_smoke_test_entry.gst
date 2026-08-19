// Phase 18.6 native smoke: target-specific runtime package selection.
//
// Phase 18 selects a package Phase 17 already built. It never defines runtime
// symbol identity or version, and the selected package's object format must
// agree with the format Patch 18.3 derived from the target's operating system.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func selection(version: str, form: str, owner: str, object_format: str, compatibility: str, ctx: &Arena) target.MirTargetPackageSelection[ctx] {
    mut value: target.MirTargetPackageSelection[ctx];
    value.target_id = std.Clone(ctx, "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8");
    value.selected_package_version = std.Clone(ctx, version);
    value.package_form = std.Clone(ctx, form);
    value.owning_authority = std.Clone(ctx, owner);
    value.declared_object_format = std.Clone(ctx, object_format);
    value.compatibility_decision = std.Clone(ctx, compatibility);
    return value;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut good := selection("gust-runtime-package-v1", "static_archive", "phase17_runtime_package_authority", "elf", "compatible", &ctx);
    mut validation := target.mir_target_package_selection_validate(good, "elf", &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    mut request := target_request.mir_serialize_target_package_request(good, "elf", &ctx);
    mut witness := target_request.mir_target_package_mir_to_c_witness(good, "elf", &ctx);
    if os.WriteFile("/tmp/gust-phase18-package.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-package.mir-to-c.witness", witness) == 0 { os.Exit(2); }

    // Rejection: a package whose format disagrees with the Patch 18.3 descriptor.
    mut wrong_format := selection("gust-runtime-package-v1", "static_archive", "phase17_runtime_package_authority", "macho", "compatible", &ctx);
    mut wrong_validation := target.mir_target_package_selection_validate(wrong_format, "elf", &ctx);
    if wrong_validation.valid == 1 || std.str_eq(wrong_validation.reason_code, "target_package_object_format_mismatch") == 0 { os.Exit(3); }

    // Rejection: a selection Phase 18 claims to own.
    mut self_owned := selection("gust-runtime-package-v1", "static_archive", "phase18_target_authority", "elf", "compatible", &ctx);
    mut self_validation := target.mir_target_package_selection_validate(self_owned, "elf", &ctx);
    if self_validation.valid == 1 || std.str_eq(self_validation.reason_code, "target_package_defined_by_phase18") == 0 { os.Exit(4); }

    // Rejection: no package at all.
    mut absent := selection("", "static_archive", "phase17_runtime_package_authority", "elf", "compatible", &ctx);
    mut absent_validation := target.mir_target_package_selection_validate(absent, "elf", &ctx);
    if absent_validation.valid == 1 || std.str_eq(absent_validation.reason_code, "target_package_missing") == 0 { os.Exit(5); }

    // Rejection: a compatibility field that is not a decision.
    mut undecided := selection("gust-runtime-package-v1", "static_archive", "phase17_runtime_package_authority", "elf", "maybe", &ctx);
    mut undecided_validation := target.mir_target_package_selection_validate(undecided, "elf", &ctx);
    if undecided_validation.valid == 1 || std.str_eq(undecided_validation.reason_code, "target_package_incompatible") == 0 { os.Exit(6); }

    os.LogStr("SUCCESS: Phase 18.6 target package selection smoke passed");
}
