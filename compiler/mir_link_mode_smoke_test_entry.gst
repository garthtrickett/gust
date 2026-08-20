// Phase 18.8 native smoke: static and dynamic runtime linking modes.
//
// A mode is available only when a Phase 17 runtime package form provides it.
// Every declared package is a static archive, so dynamic is unavailable and a
// request for it is refused rather than silently downgraded to static.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func decision(package_form: str, selected: str, ctx: &Arena) target.MirLinkModeDecision[ctx] {
    mut value: target.MirLinkModeDecision[ctx];
    value.target_id = std.Clone(ctx, "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8");
    value.required_package_form = std.Clone(ctx, package_form);
    value.selected_mode = std.Clone(ctx, selected);
    return value;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    if std.str_eq(target.mir_link_mode_for_package_form("static_archive", &ctx), "static") == 0 { os.Exit(1); }
    if std.str_eq(target.mir_link_mode_for_package_form("shared_library", &ctx), "dynamic") == 0 { os.Exit(2); }
    if std.str_eq(target.mir_link_mode_for_package_form("loose_objects", &ctx), "") == 0 { os.Exit(3); }

    mut good := decision("static_archive", "static", &ctx);
    mut validation := target.mir_link_mode_validate(good, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(4); }

    mut request := target_request.mir_serialize_link_mode_request(good, &ctx);
    mut witness := target_request.mir_link_mode_mir_to_c_witness(good, &ctx);
    if os.WriteFile("/tmp/gust-phase18-linkmode.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-linkmode.mir-to-c.witness", witness) == 0 { os.Exit(5); }

    // Rejection: dynamic requested when only a static archive exists.
    mut unavailable := decision("static_archive", "dynamic", &ctx);
    mut unavailable_validation := target.mir_link_mode_validate(unavailable, &ctx);
    if unavailable_validation.valid == 1 || std.str_eq(unavailable_validation.reason_code, "link_mode_unavailable_for_target") == 0 { os.Exit(6); }

    // Rejection: a mode outside the declared vocabulary.
    mut unknown := decision("static_archive", "lazy", &ctx);
    mut unknown_validation := target.mir_link_mode_validate(unknown, &ctx);
    if unknown_validation.valid == 1 || std.str_eq(unknown_validation.reason_code, "link_mode_unknown") == 0 { os.Exit(7); }

    // Rejection: a package form that provides no mode at all.
    mut bad_form := decision("loose_objects", "static", &ctx);
    mut bad_form_validation := target.mir_link_mode_validate(bad_form, &ctx);
    if bad_form_validation.valid == 1 || std.str_eq(bad_form_validation.reason_code, "link_mode_package_form_mismatch") == 0 { os.Exit(8); }


    // AUDIT (18.18): a decision naming no package form selected its mode without
    // consulting the package authority at all. This is checked before the
    // package-form lookup, which would otherwise swallow it as a mismatch.
    mut evidenceless := target.mir_link_mode_validate(decision("", "static", &ctx), &ctx);
    if evidenceless.valid == 1 || std.str_eq(evidenceless.reason_code, "link_mode_selected_without_package_evidence") == 0 { os.Exit(20); }

    // Sentinel: a named but unrecognised form is a DIFFERENT fault and keeps its
    // own class, proving the check above is not just catching everything empty.
    mut unrecognised := target.mir_link_mode_validate(decision("loose_objects", "static", &ctx), &ctx);
    if unrecognised.valid == 1 || std.str_eq(unrecognised.reason_code, "link_mode_selected_without_package_evidence") == 1 { os.Exit(21); }

    os.LogStr("SUCCESS: Phase 18.8 link mode smoke passed");
}
