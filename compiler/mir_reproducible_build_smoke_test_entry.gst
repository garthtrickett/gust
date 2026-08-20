// Phase 18.15 native smoke: reproducible object and artifact output.
//
// Reproducibility depends on everything that shapes emitted bytes, so the
// optimisation level and debug plan are inputs to the guarantee rather than
// incidental. A field cannot be both guaranteed and disclaimed, and an
// exclusion without a reason is a silently narrowed guarantee.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func build(level: str, debug_plan: str, field_value: str, excluded_reason: str, repeated: int, path_form: str, order_source: str, ctx: &Arena) target.MirReproducibleBuild[ctx] {
    mut value: target.MirReproducibleBuild[ctx];
    value.target_id = std.Clone(ctx, "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8");
    value.optimisation_level = std.Clone(ctx, level);
    value.debug_plan = std.Clone(ctx, debug_plan);
    value.reproducible_field_value = std.Clone(ctx, field_value);
    value.excluded_field_reason = std.Clone(ctx, excluded_reason);
    value.repeated_build_compared = repeated;
    value.embedded_path_form = std.Clone(ctx, path_form);
    value.order_source = std.Clone(ctx, order_source);
    return value;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut good := build("basic", "line_tables_only", "0x40", "wall_clock_is_not_a_property_of_the_input", 1, "relative_to_source_root", "compiler_produced_order", &ctx);
    mut validation := target.mir_reproducible_build_validate(good, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    // Reproducibility needs TWO builds. A claim made from a single build is a
    // claim about nothing, so both the request and the witness carry the repeat.
    mut repeat := build("basic", "line_tables_only", "0x40", "wall_clock_is_not_a_property_of_the_input", 1, "relative_to_source_root", "compiler_produced_order", &ctx);
    mut request := target_request.mir_serialize_reproducibility_request(good, repeat, &ctx);
    mut witness := target_request.mir_reproducibility_mir_to_c_witness(good, repeat, &ctx);
    if os.WriteFile("/tmp/gust-phase18-repro.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-repro.mir-to-c.witness", witness) == 0 { os.Exit(2); }

    // Rejection: reproducibility claimed without actually repeating the build.
    mut unrepeated := build("basic", "line_tables_only", "0x40", "wall_clock_is_not_a_property_of_the_input", 0, "relative_to_source_root", "compiler_produced_order", &ctx);
    mut unrepeated_validation := target.mir_reproducible_build_validate(unrepeated, &ctx);
    if unrepeated_validation.valid == 1 || std.str_eq(unrepeated_validation.reason_code, "reproducibility_claimed_without_a_repeated_build") == 0 { os.Exit(3); }

    // Rejection: an exclusion that states no reason.
    mut unreasoned := build("basic", "line_tables_only", "0x40", "", 1, "relative_to_source_root", "compiler_produced_order", &ctx);
    mut unreasoned_validation := target.mir_reproducible_build_validate(unreasoned, &ctx);
    if unreasoned_validation.valid == 1 || std.str_eq(unreasoned_validation.reason_code, "excluded_field_not_declared") == 0 { os.Exit(4); }

    // Rejection: a build naming no optimisation level. The level changes emitted
    // bytes, so a build that does not name one has not said what it is a build
    // OF. That is an undeclared input, not a field that varied between builds.
    mut levelless := build("", "line_tables_only", "0x40", "wall_clock_is_not_a_property_of_the_input", 1, "relative_to_source_root", "compiler_produced_order", &ctx);
    mut levelless_validation := target.mir_reproducible_build_validate(levelless, &ctx);
    if levelless_validation.valid == 1 || std.str_eq(levelless_validation.reason_code, "reproducibility_input_undeclared") == 0 { os.Exit(5); }

    // Rejection: a build naming no debug plan, for the same reason.
    mut planless := build("basic", "", "0x40", "wall_clock_is_not_a_property_of_the_input", 1, "relative_to_source_root", "compiler_produced_order", &ctx);
    mut planless_validation := target.mir_reproducible_build_validate(planless, &ctx);
    if planless_validation.valid == 1 || std.str_eq(planless_validation.reason_code, "reproducibility_input_undeclared") == 0 { os.Exit(6); }


    // Rejection: an embedded path recorded in a form the normalisation rules
    // do not permit.
    mut absolute := build("basic", "line_tables_only", "0x40", "", 1, "absolute_host_path", "compiler_produced_order", &ctx);
    mut absolute_validation := target.mir_reproducibility_normalisation_validate(absolute, &ctx);
    if absolute_validation.valid == 1 || std.str_eq(absolute_validation.reason_code, "normalisation_rule_not_applied") == 0 { os.Exit(11); }

    // Rejection: order taken from a source that is not the compiler's own.
    mut unordered := build("basic", "line_tables_only", "0x40", "", 1, "relative_to_source_root", "hash_table_iteration", &ctx);
    mut unordered_validation := target.mir_reproducibility_normalisation_validate(unordered, &ctx);
    if unordered_validation.valid == 1 || std.str_eq(unordered_validation.reason_code, "nondeterministic_order_in_a_reproducible_field") == 0 { os.Exit(12); }

    // Sentinel: a build declaring both normalised forms is accepted, so the two
    // refusals above came from the declared forms and not from the build shape.
    mut normalised := build("basic", "line_tables_only", "0x40", "", 1, "relative_to_source_root", "compiler_produced_order", &ctx);
    if target.mir_reproducibility_normalisation_validate(normalised, &ctx).valid == 0 { os.Exit(13); }

    os.LogStr("SUCCESS: Phase 18.15 reproducibility smoke passed");
}
