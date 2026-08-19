// Phase 18.5 native smoke: target-specific ABI selection.
//
// Phase 18 selects an ABI Phase 16 already accepts. Selecting anything else,
// including a platform calling convention, would be Phase 18 defining ABI
// semantics rather than choosing among what exists.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func accepted_abi() str { return "gust_canonical_v1"; }

func selection(abi_id: str, owner: str, compatibility: str, platform_status: str, ctx: &Arena) target.MirTargetAbiSelection[ctx] {
    mut value: target.MirTargetAbiSelection[ctx];
    value.target_id = std.Clone(ctx, "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8");
    value.selected_abi_id = std.Clone(ctx, abi_id);
    value.owning_authority = std.Clone(ctx, owner);
    value.compatibility_decision = std.Clone(ctx, compatibility);
    value.platform_convention_status = std.Clone(ctx, platform_status);
    return value;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut good := selection(accepted_abi(), "compiler/mir_cross_module_abi.gst", "compatible", "deferred_to_a_later_abi_phase", &ctx);
    mut validation := target.mir_target_abi_selection_validate(good, accepted_abi(), &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    mut request := target_request.mir_serialize_target_abi_request(good, accepted_abi(), &ctx);
    mut witness := target_request.mir_target_abi_mir_to_c_witness(good, accepted_abi(), &ctx);
    if os.WriteFile("/tmp/gust-phase18-abi.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-abi.mir-to-c.witness", witness) == 0 { os.Exit(2); }

    // Rejection: an ABI Phase 16 does not accept.
    mut invented := selection("sysv_x86_64", "compiler/mir_cross_module_abi.gst", "compatible", "deferred_to_a_later_abi_phase", &ctx);
    mut invented_validation := target.mir_target_abi_selection_validate(invented, accepted_abi(), &ctx);
    if invented_validation.valid == 1 || std.str_eq(invented_validation.reason_code, "target_abi_undeclared_by_phase16") == 0 { os.Exit(3); }

    // Rejection: a selection with no owner.
    mut ownerless := selection(accepted_abi(), "", "compatible", "deferred_to_a_later_abi_phase", &ctx);
    mut ownerless_validation := target.mir_target_abi_selection_validate(ownerless, accepted_abi(), &ctx);
    if ownerless_validation.valid == 1 || std.str_eq(ownerless_validation.reason_code, "target_abi_selection_missing") == 0 { os.Exit(4); }

    // Rejection: a compatibility field that is not a decision.
    mut undecided := selection(accepted_abi(), "compiler/mir_cross_module_abi.gst", "probably", "deferred_to_a_later_abi_phase", &ctx);
    mut undecided_validation := target.mir_target_abi_selection_validate(undecided, accepted_abi(), &ctx);
    if undecided_validation.valid == 1 || std.str_eq(undecided_validation.reason_code, "target_abi_incompatible") == 0 { os.Exit(5); }

    // Rejection: a target claiming a platform calling convention.
    mut platform := selection(accepted_abi(), "compiler/mir_cross_module_abi.gst", "compatible", "selected_sysv", &ctx);
    mut platform_validation := target.mir_target_abi_selection_validate(platform, accepted_abi(), &ctx);
    if platform_validation.valid == 1 || std.str_eq(platform_validation.reason_code, "target_abi_platform_convention_selected_without_phase16_support") == 0 { os.Exit(6); }

    os.LogStr("SUCCESS: Phase 18.5 target ABI selection smoke passed");
}
