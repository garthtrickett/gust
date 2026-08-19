// Phase 18.3 native smoke: object format, section, and symbol binding.
//
// The format follows from the operating system in the declared target identity.
// A descriptor claiming a format that operating system does not imply, or one
// that does not say it was derived from target identity, is a host default
// wearing a descriptor's clothes.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func linux_x86_64_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func section(kind: str, name: str, alignment: int, ctx: &Arena) target.MirObjectSection[ctx] {
    mut value: target.MirObjectSection[ctx];
    value.section_kind = std.Clone(ctx, kind);
    value.section_name = std.Clone(ctx, name);
    value.alignment = alignment;
    return value;
}

func descriptor(object_format: str, derived_from: str, max_align: int, first_name: str, first_align: int, ctx: &Arena) target.MirObjectFormatDescriptor[ctx] {
    mut value: target.MirObjectFormatDescriptor[ctx];
    value.target_id = std.Clone(ctx, linux_x86_64_id());
    value.object_format = std.Clone(ctx, object_format);
    value.derived_from = std.Clone(ctx, derived_from);
    value.max_section_alignment = max_align;
    mut sections: std.Vector[target.MirObjectSection[ctx], ctx] := std.VectorNew(ctx);
    sections.Push(section("text", first_name, first_align, ctx));
    sections.Push(section("read_only_data", ".rodata", 8, ctx));
    sections.Push(section("data", ".data", 8, ctx));
    sections.Push(section("zero_initialised_data", ".bss", 8, ctx));
    mut section_index: Index[std.Vector[target.MirObjectSection[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(section_index, sections);
    value.sections = section_index;
    mut bindings: std.Vector[str, ctx] := std.VectorNew(ctx);
    bindings.Push(std.Clone(ctx, "local"));
    bindings.Push(std.Clone(ctx, "global"));
    bindings.Push(std.Clone(ctx, "weak"));
    mut binding_index: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(binding_index, bindings);
    value.symbol_bindings = binding_index;
    mut visibilities: std.Vector[str, ctx] := std.VectorNew(ctx);
    visibilities.Push(std.Clone(ctx, "default"));
    visibilities.Push(std.Clone(ctx, "hidden"));
    mut visibility_index: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(visibility_index, visibilities);
    value.symbol_visibilities = visibility_index;
    return value;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    if std.str_eq(target.mir_object_format_for_operating_system("linux", &ctx), "elf") == 0 { os.Exit(1); }
    if std.str_eq(target.mir_object_format_for_operating_system("darwin", &ctx), "macho") == 0 { os.Exit(2); }
    if std.str_eq(target.mir_object_format_for_operating_system("plan9", &ctx), "") == 0 { os.Exit(3); }

    mut good := descriptor("elf", "operating_system_in_declared_target_identity", 16, ".text", 16, &ctx);
    mut validation := target.mir_object_format_validate(good, "linux", &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(4); }
    if target.mir_object_section_declared(good, "text", &ctx) == 0 { os.Exit(5); }
    if target.mir_object_section_declared(good, "debug", &ctx) == 1 { os.Exit(6); }
    if target.mir_object_binding_declared(good, "global", &ctx) == 0 { os.Exit(7); }
    if target.mir_object_binding_declared(good, "exported", &ctx) == 1 { os.Exit(8); }

    mut request := target_request.mir_serialize_object_format_request(good, "linux", &ctx);
    mut witness := target_request.mir_object_format_mir_to_c_witness(good, "linux", &ctx);
    if os.WriteFile("/tmp/gust-phase18-objfmt.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-objfmt.mir-to-c.witness", witness) == 0 { os.Exit(9); }

    // Rejection: a format the operating system does not imply.
    mut wrong := descriptor("macho", "operating_system_in_declared_target_identity", 16, ".text", 16, &ctx);
    mut wrong_validation := target.mir_object_format_validate(wrong, "linux", &ctx);
    if wrong_validation.valid == 1 || std.str_eq(wrong_validation.reason_code, "object_format_disagrees_with_target_identity") == 0 { os.Exit(10); }

    // Rejection: a format that does not say it came from target identity.
    mut undeclared := descriptor("elf", "host_default", 16, ".text", 16, &ctx);
    mut undeclared_validation := target.mir_object_format_validate(undeclared, "linux", &ctx);
    if undeclared_validation.valid == 1 || std.str_eq(undeclared_validation.reason_code, "object_format_not_derived_from_target_identity") == 0 { os.Exit(11); }

    // Rejection: an unknown operating system has no format at all.
    mut unknown_validation := target.mir_object_format_validate(good, "plan9", &ctx);
    if unknown_validation.valid == 1 || std.str_eq(unknown_validation.reason_code, "object_format_unknown_operating_system") == 0 { os.Exit(12); }

    // Rejection: a section aligned beyond the declared maximum.
    mut overaligned := descriptor("elf", "operating_system_in_declared_target_identity", 16, ".text", 32, &ctx);
    mut overaligned_validation := target.mir_object_format_validate(overaligned, "linux", &ctx);
    if overaligned_validation.valid == 1 || std.str_eq(overaligned_validation.reason_code, "object_section_misaligned") == 0 { os.Exit(13); }

    // Rejection: an unnamed section.
    mut unnamed := descriptor("elf", "operating_system_in_declared_target_identity", 16, "", 16, &ctx);
    mut unnamed_validation := target.mir_object_format_validate(unnamed, "linux", &ctx);
    if unnamed_validation.valid == 1 || std.str_eq(unnamed_validation.reason_code, "object_section_unnamed") == 0 { os.Exit(14); }

    os.LogStr("SUCCESS: Phase 18.3 object format smoke passed");
}
