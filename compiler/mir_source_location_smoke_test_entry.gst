// Phase 18.13 native smoke: source-location preservation.
//
// A location produced by the compiler survives lowering wherever the debug plan
// requires it. Inventing a plausible span for code the source did not write is
// worse than admitting the gap, because a debugger will confidently point at
// the wrong line.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func location(file: str, span: str, mir: str, emitted: str, fabricated: int, ctx: &Arena) target.MirSourceLocation[ctx] {
    mut value: target.MirSourceLocation[ctx];
    value.source_file = std.Clone(ctx, file);
    value.source_span = std.Clone(ctx, span);
    value.canonical_mir_association = std.Clone(ctx, mir);
    value.emitted_debug_association = std.Clone(ctx, emitted);
    value.fabricated = fabricated;
    return value;
}


// The set validators build an arena Index, and `Index[std.Vector[T[ctx], ctx], ctx]`
// needs the [ctx] generic parameter that func main() does not carry. So the set
// construction lives in helpers, which is what every other smoke entry does.
func validate_location_set(locations: std.Vector[target.MirSourceLocation[ctx], ctx], requires_locations: int, ctx: &Arena) target.MirSourceLocationValidation[ctx] {
    mut locations_index: Index[std.Vector[target.MirSourceLocation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(locations_index, locations);
    return target.mir_source_location_set_validate(locations_index, requires_locations, ctx);
}

func duplicated_set_validation(ctx: &Arena) target.MirSourceLocationValidation[ctx] {
    mut locations: std.Vector[target.MirSourceLocation[ctx], ctx] := std.VectorNew(ctx);
    locations.Push(location("compiler/example.gst", "12:5-12:20", "mir.block.3", "dwarf.line.7", 0, ctx));
    locations.Push(location("compiler/example.gst", "13:5-13:20", "mir.block.3", "dwarf.line.8", 0, ctx));
    return validate_location_set(locations, 1, ctx);
}

func absent_set_validation(requires_locations: int, ctx: &Arena) target.MirSourceLocationValidation[ctx] {
    mut locations: std.Vector[target.MirSourceLocation[ctx], ctx] := std.VectorNew(ctx);
    return validate_location_set(locations, requires_locations, ctx);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut good := location("compiler/example.gst", "12:5-12:20", "mir.block.3", "dwarf.line.7", 0, &ctx);
    mut validation := target.mir_source_location_validate(good, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    mut request := target_request.mir_serialize_source_location_request(good, &ctx);
    mut witness := target_request.mir_source_location_mir_to_c_witness(good, &ctx);
    if os.WriteFile("/tmp/gust-phase18-srcloc.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-srcloc.mir-to-c.witness", witness) == 0 { os.Exit(2); }

    // Rejection: a location fabricated for code with no source span.
    mut fabricated := location("compiler/example.gst", "", "mir.block.9", "dwarf.line.11", 1, &ctx);
    mut fabricated_validation := target.mir_source_location_validate(fabricated, &ctx);
    if fabricated_validation.valid == 1 || std.str_eq(fabricated_validation.reason_code, "source_location_fabricated_without_a_source_span") == 0 { os.Exit(3); }

    // Rejection: a location lost between canonical MIR and emitted records.
    mut lost := location("compiler/example.gst", "12:5-12:20", "mir.block.3", "", 0, &ctx);
    mut lost_validation := target.mir_source_location_validate(lost, &ctx);
    if lost_validation.valid == 1 || std.str_eq(lost_validation.reason_code, "source_location_lost_in_lowering") == 0 { os.Exit(4); }

    // Rejection: a location with no canonical MIR association was reconstructed
    // by the backend rather than produced by the compiler.
    mut reconstructed := location("compiler/example.gst", "12:5-12:20", "", "dwarf.line.7", 0, &ctx);
    mut reconstructed_validation := target.mir_source_location_validate(reconstructed, &ctx);
    if reconstructed_validation.valid == 1 || std.str_eq(reconstructed_validation.reason_code, "source_location_reconstructed_by_backend") == 0 { os.Exit(5); }

    // Rejection: a location naming no source file at all.
    mut fileless := location("", "12:5-12:20", "mir.block.3", "dwarf.line.7", 0, &ctx);
    mut fileless_validation := target.mir_source_location_validate(fileless, &ctx);
    if fileless_validation.valid == 1 || std.str_eq(fileless_validation.reason_code, "source_location_fabricated_without_a_source_span") == 0 { os.Exit(6); }


    // Rejection: two locations naming the same canonical MIR instruction. This
    // is a property of the set, so it needs the set validator.
    mut duplicated_validation := duplicated_set_validation(&ctx);
    if duplicated_validation.valid == 1 || std.str_eq(duplicated_validation.reason_code, "source_location_duplicated_for_one_instruction") == 0 { os.Exit(7); }

    // Rejection: the debug plan requires a line table and no location exists.
    mut missing_validation := absent_set_validation(1, &ctx);
    if missing_validation.valid == 1 || std.str_eq(missing_validation.reason_code, "source_location_missing_where_the_debug_plan_requires_it") == 0 { os.Exit(8); }

    // Sentinel: the same empty set is accepted when the plan requires nothing,
    // proving the refusal above came from the requirement and not from emptiness.
    mut permitted := absent_set_validation(0, &ctx);
    if permitted.valid == 0 { os.Exit(9); }

    os.LogStr("SUCCESS: Phase 18.13 source location smoke passed");
}
