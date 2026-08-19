// Phase 18.4 native smoke: relocation model and validation.
//
// A relocation is a compiler-owned decision, not an emitted side effect. Every
// relocation is validated before the object is published and before the linker
// runs, so an invalid one cannot replace a valid artifact. Zero-initialised
// data holds no bytes, so it can hold no relocation.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func linux_x86_64_id() str {
    return "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8";
}

func model(stage: str, ctx: &Arena) target.MirRelocationModel[ctx] {
    mut value: target.MirRelocationModel[ctx];
    value.target_id = std.Clone(ctx, linux_x86_64_id());
    value.object_format = std.Clone(ctx, "elf");
    value.architecture = std.Clone(ctx, "x86_64");
    value.addend_policy = std.Clone(ctx, "explicit_addend_required_for_absolute_kinds_zero_for_relative_kinds");
    value.validation_stage = std.Clone(ctx, stage);
    mut kinds: std.Vector[str, ctx] := std.VectorNew(ctx);
    kinds.Push(std.Clone(ctx, "R_X86_64_64"));
    kinds.Push(std.Clone(ctx, "R_X86_64_PC32"));
    kinds.Push(std.Clone(ctx, "R_X86_64_PLT32"));
    mut kind_index: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(kind_index, kinds);
    value.relocation_kinds = kind_index;
    mut sections: std.Vector[str, ctx] := std.VectorNew(ctx);
    sections.Push(std.Clone(ctx, "text"));
    sections.Push(std.Clone(ctx, "read_only_data"));
    sections.Push(std.Clone(ctx, "data"));
    mut section_index: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(section_index, sections);
    value.permitted_section_kinds = section_index;
    return value;
}

func relocation(kind: str, section_kind: str, offset: int, addend: int, symbol: str, ctx: &Arena) target.MirRelocation[ctx] {
    mut value: target.MirRelocation[ctx];
    value.relocation_kind = std.Clone(ctx, kind);
    value.section_kind = std.Clone(ctx, section_kind);
    value.offset = offset;
    value.addend = addend;
    value.symbol_identity = std.Clone(ctx, symbol);
    return value;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut good_model := model("before_object_publication_and_before_linker_invocation", &ctx);

    if target.mir_relocation_kind_declared(good_model, "R_X86_64_64", &ctx) == 0 { os.Exit(1); }
    if target.mir_relocation_kind_declared(good_model, "R_AARCH64_ABS64", &ctx) == 1 { os.Exit(2); }
    if target.mir_relocation_section_permitted(good_model, "text", &ctx) == 0 { os.Exit(3); }
    if target.mir_relocation_section_permitted(good_model, "zero_initialised_data", &ctx) == 1 { os.Exit(4); }
    if target.mir_relocation_kind_is_absolute("R_X86_64_64", &ctx) == 0 { os.Exit(5); }
    if target.mir_relocation_kind_is_absolute("R_X86_64_PC32", &ctx) == 1 { os.Exit(6); }

    // Accepting: an absolute relocation stating its addend.
    mut absolute := relocation("R_X86_64_64", "text", 16, 8, "gust_rt_symbol", &ctx);
    mut absolute_validation := target.mir_relocation_validate(good_model, absolute, &ctx);
    if absolute_validation.valid == 0 { os.LogStr(absolute_validation.reason_code); os.Exit(7); }

    // Accepting: a relative relocation with no addend.
    mut relative := relocation("R_X86_64_PC32", "text", 32, 0, "gust_rt_symbol", &ctx);
    mut relative_validation := target.mir_relocation_validate(good_model, relative, &ctx);
    if relative_validation.valid == 0 { os.LogStr(relative_validation.reason_code); os.Exit(8); }

    mut request := target_request.mir_serialize_relocation_request(good_model, absolute, &ctx);
    mut witness := target_request.mir_relocation_mir_to_c_witness(good_model, absolute, &ctx);
    if os.WriteFile("/tmp/gust-phase18-reloc.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-reloc.mir-to-c.witness", witness) == 0 { os.Exit(9); }

    // Rejection: a kind outside the declared vocabulary.
    mut unknown := relocation("R_X86_64_GOTPCREL", "text", 16, 0, "gust_rt_symbol", &ctx);
    mut unknown_validation := target.mir_relocation_validate(good_model, unknown, &ctx);
    if unknown_validation.valid == 1 || std.str_eq(unknown_validation.reason_code, "relocation_kind_unknown") == 0 { os.Exit(10); }

    // Rejection: a relocation in a section that holds no bytes.
    mut in_bss := relocation("R_X86_64_64", "zero_initialised_data", 16, 8, "gust_rt_symbol", &ctx);
    mut in_bss_validation := target.mir_relocation_validate(good_model, in_bss, &ctx);
    if in_bss_validation.valid == 1 || std.str_eq(in_bss_validation.reason_code, "relocation_in_disallowed_section") == 0 { os.Exit(11); }

    // Rejection: a relative relocation carrying an addend.
    mut bad_addend := relocation("R_X86_64_PC32", "text", 32, 4, "gust_rt_symbol", &ctx);
    mut bad_addend_validation := target.mir_relocation_validate(good_model, bad_addend, &ctx);
    if bad_addend_validation.valid == 1 || std.str_eq(bad_addend_validation.reason_code, "relocation_addend_malformed") == 0 { os.Exit(12); }

    // Rejection: a relocation with no symbol.
    mut no_symbol := relocation("R_X86_64_64", "text", 16, 8, "", &ctx);
    mut no_symbol_validation := target.mir_relocation_validate(good_model, no_symbol, &ctx);
    if no_symbol_validation.valid == 1 || std.str_eq(no_symbol_validation.reason_code, "relocation_symbol_missing") == 0 { os.Exit(13); }

    // Rejection: a model that validates after output could already exist.
    mut late_model := model("during_output_replacement", &ctx);
    mut late_validation := target.mir_relocation_validate(late_model, absolute, &ctx);
    if late_validation.valid == 1 || std.str_eq(late_validation.reason_code, "relocation_validated_too_late") == 0 { os.Exit(14); }

    os.LogStr("SUCCESS: Phase 18.4 relocation model smoke passed");
}
