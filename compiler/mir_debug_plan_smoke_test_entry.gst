// Phase 18.12 native smoke: debug information strategy.
//
// The debug plan is compiler-selected and derived from the object format. A
// plan must say what it emits and what it does not, and a record kind cannot
// be both promised and disclaimed.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func plan(debug_format: str, derived: str, level: str, included: str, excluded: str, ctx: &Arena) target.MirDebugPlan[ctx] {
    mut value: target.MirDebugPlan[ctx];
    value.target_id = std.Clone(ctx, "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8");
    value.debug_format = std.Clone(ctx, debug_format);
    value.derived_from = std.Clone(ctx, derived);
    value.debug_level = std.Clone(ctx, level);
    value.included_kind = std.Clone(ctx, included);
    value.excluded_kind = std.Clone(ctx, excluded);
    return value;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut good := plan("dwarf", "object_format_in_the_phase18_object_format_authority", "line_tables_only", "line_table", "variable_location", &ctx);
    mut validation := target.mir_debug_plan_validate(good, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(1); }

    mut request := target_request.mir_serialize_debug_plan_request(good, &ctx);
    mut witness := target_request.mir_debug_plan_mir_to_c_witness(good, &ctx);
    if os.WriteFile("/tmp/gust-phase18-debug.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-debug.mir-to-c.witness", witness) == 0 { os.Exit(2); }

    // Rejection: a level outside the declared vocabulary.
    mut bad_level := plan("dwarf", "object_format_in_the_phase18_object_format_authority", "full", "line_table", "variable_location", &ctx);
    mut level_validation := target.mir_debug_plan_validate(bad_level, &ctx);
    if level_validation.valid == 1 || std.str_eq(level_validation.reason_code, "debug_level_unknown") == 0 { os.Exit(3); }

    // Rejection: a plan the backend inferred rather than the compiler selecting.
    mut inferred := plan("dwarf", "backend_default", "line_tables_only", "line_table", "variable_location", &ctx);
    mut inferred_validation := target.mir_debug_plan_validate(inferred, &ctx);
    if inferred_validation.valid == 1 || std.str_eq(inferred_validation.reason_code, "debug_plan_inferred_by_backend") == 0 { os.Exit(4); }

    // Rejection: a record kind both promised and disclaimed.
    mut contradictory := plan("dwarf", "object_format_in_the_phase18_object_format_authority", "line_tables_only", "line_table", "line_table", &ctx);
    mut contradictory_validation := target.mir_debug_plan_validate(contradictory, &ctx);
    if contradictory_validation.valid == 1 || std.str_eq(contradictory_validation.reason_code, "debug_record_kind_undeclared") == 0 { os.Exit(5); }

    // Rejection: a plan that says nothing about what it does not emit.
    mut silent := plan("dwarf", "object_format_in_the_phase18_object_format_authority", "line_tables_only", "line_table", "", &ctx);
    mut silent_validation := target.mir_debug_plan_validate(silent, &ctx);
    if silent_validation.valid == 1 || std.str_eq(silent_validation.reason_code, "debug_record_kind_undeclared") == 0 { os.Exit(6); }

    os.LogStr("SUCCESS: Phase 18.12 debug information smoke passed");
}
