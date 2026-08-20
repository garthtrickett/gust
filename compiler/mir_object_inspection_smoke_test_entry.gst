// Phase 18.11 native smoke: symbol and relocation inspection evidence.
//
// Inspection observes and compares; it never decides. An inspected symbol,
// binding, section, or relocation kind must trace to a compiler-produced
// record. Inspection supplying a fact the compiler did not produce would make
// the object file a second source of truth.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func observation(symbol: str, binding: str, section: str, kind: str, planned: int, ctx: &Arena) target.MirObjectObservation[ctx] {
    mut value: target.MirObjectObservation[ctx];
    value.symbol_name = std.Clone(ctx, symbol);
    value.binding = std.Clone(ctx, binding);
    value.section_kind = std.Clone(ctx, section);
    value.relocation_kind = std.Clone(ctx, kind);
    value.in_compiler_plan = planned;
    return value;
}


// AUDIT (18.18): inspection could report a symbol the plan did not contain, but
// never the reverse. A plan promising a symbol the object does not hold is the
// more dangerous direction -- the link succeeds and the program is wrong.
// Absence is a property of the set, so this needs a set of observations.
func observed_set(ctx: &Arena) Index[std.Vector[target.MirObjectObservation[ctx], ctx], ctx] {
    mut values: std.Vector[target.MirObjectObservation[ctx], ctx] := std.VectorNew(ctx);
    values.Push(observation("gust_rt_symbol", "global", "text", "R_X86_64_64", 1, ctx));
    mut index: Index[std.Vector[target.MirObjectObservation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(index, values);
    return index;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    // Accepting: an observation matching the compiler-produced plan.
    mut good := observation("gust_rt_symbol", "global", "text", "R_X86_64_64", 1, &ctx);
    mut validation := target.mir_object_observation_validate(good, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    mut request := target_request.mir_serialize_object_inspection_request(good, &ctx);
    mut witness := target_request.mir_object_inspection_mir_to_c_witness(good, &ctx);
    if os.WriteFile("/tmp/gust-phase18-inspect.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-inspect.mir-to-c.witness", witness) == 0 { os.Exit(2); }

    // Rejection: a symbol the compiler never planned.
    mut unplanned := observation("mystery_symbol", "global", "text", "R_X86_64_64", 0, &ctx);
    mut unplanned_validation := target.mir_object_observation_validate(unplanned, &ctx);
    if unplanned_validation.valid == 1 || std.str_eq(unplanned_validation.reason_code, "inspected_symbol_not_in_compiler_plan") == 0 { os.Exit(3); }

    // Rejection: a binding outside the declared vocabulary.
    mut bad_binding := observation("gust_rt_symbol", "exported", "text", "R_X86_64_64", 1, &ctx);
    mut binding_validation := target.mir_object_observation_validate(bad_binding, &ctx);
    if binding_validation.valid == 1 || std.str_eq(binding_validation.reason_code, "inspected_binding_outside_declared_vocabulary") == 0 { os.Exit(4); }

    // Rejection: a section outside the declared vocabulary.
    mut bad_section := observation("gust_rt_symbol", "global", "debug_info", "R_X86_64_64", 1, &ctx);
    mut section_validation := target.mir_object_observation_validate(bad_section, &ctx);
    if section_validation.valid == 1 || std.str_eq(section_validation.reason_code, "inspected_section_outside_declared_vocabulary") == 0 { os.Exit(5); }

    // Rejection: a relocation in a section that holds no bytes.
    mut in_bss := observation("gust_rt_symbol", "global", "zero_initialised_data", "R_X86_64_64", 1, &ctx);
    mut bss_validation := target.mir_object_observation_validate(in_bss, &ctx);
    if bss_validation.valid == 1 || std.str_eq(bss_validation.reason_code, "inspected_relocation_in_disallowed_section") == 0 { os.Exit(6); }

    // Rejection: a relocation kind no declared model permits.
    mut bad_kind := observation("gust_rt_symbol", "global", "text", "R_X86_64_GOTPCREL", 1, &ctx);
    mut kind_validation := target.mir_object_observation_validate(bad_kind, &ctx);
    if kind_validation.valid == 1 || std.str_eq(kind_validation.reason_code, "inspected_relocation_kind_not_in_model") == 0 { os.Exit(7); }


    // AUDIT (18.18): the plan promises a symbol the inspected object does not hold.
    mut absent := target.mir_object_inspection_expects(observed_set(&ctx), "gust_rt_missing", &ctx);
    if absent.valid == 1 || std.str_eq(absent.reason_code, "inspected_object_missing_expected_symbol") == 0 { os.Exit(20); }

    // Sentinel: a symbol that IS present is accepted, so the refusal came from
    // absence rather than from the set being consulted at all.
    if target.mir_object_inspection_expects(observed_set(&ctx), "gust_rt_symbol", &ctx).valid == 0 { os.Exit(21); }

    os.LogStr("SUCCESS: Phase 18.11 object inspection smoke passed");
}
