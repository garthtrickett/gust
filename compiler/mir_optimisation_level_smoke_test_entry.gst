// Phase 18.14 native smoke: optimisation-level policy.
//
// A level may change the emitted instruction sequence, code size, compile time,
// or debug record density. It may never change observable program behaviour.
// The unoptimised level must actually be unoptimised, or the comparison it
// anchors is between two optimised builds.

import "mir_target_authority.gst" as target;
import "mir_target_request.gst" as target_request;

func decision(level: str, transformation: str, selected_by: str, observable_changed: int, line_table_preserved: int, ctx: &Arena) target.MirOptimisationDecision[ctx] {
    mut value: target.MirOptimisationDecision[ctx];
    value.target_id = std.Clone(ctx, "target:v1:triple=x86_64-unknown-linux-gnu:endian=little:ptr_size=8:ptr_align=8:i32_align=4:i64_align=8:max_align=8");
    value.selected_level = std.Clone(ctx, level);
    value.transformation = std.Clone(ctx, transformation);
    value.selected_by = std.Clone(ctx, selected_by);
    value.observable_behaviour_changed = observable_changed;
    value.line_table_preserved = line_table_preserved;
    return value;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    if target.mir_optimisation_level_is_declared("none", &ctx) == 0 { os.Exit(1); }
    if target.mir_optimisation_level_is_declared("basic", &ctx) == 0 { os.Exit(2); }
    if target.mir_optimisation_level_is_declared("aggressive", &ctx) == 1 { os.Exit(3); }

    mut good := decision("basic", "dead_code_elimination", "compiler", 0, 1, &ctx);
    mut validation := target.mir_optimisation_decision_validate(good, &ctx);
    if validation.valid == 0 { os.LogStr(validation.reason_code); os.Exit(4); }

    // Accepting: the unoptimised level declaring no transformation.
    mut baseline := decision("none", "", "compiler", 0, 1, &ctx);
    mut baseline_validation := target.mir_optimisation_decision_validate(baseline, &ctx);
    if baseline_validation.valid == 0 { os.LogStr(baseline_validation.reason_code); os.Exit(5); }

    mut request := target_request.mir_serialize_optimisation_request(good, &ctx);
    mut witness := target_request.mir_optimisation_mir_to_c_witness(good, &ctx);
    if os.WriteFile("/tmp/gust-phase18-opt.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase18-opt.mir-to-c.witness", witness) == 0 { os.Exit(6); }

    // Rejection: a level outside the declared vocabulary.
    mut unknown := decision("aggressive", "dead_code_elimination", "compiler", 0, 1, &ctx);
    mut unknown_validation := target.mir_optimisation_decision_validate(unknown, &ctx);
    if unknown_validation.valid == 1 || std.str_eq(unknown_validation.reason_code, "optimisation_level_unknown") == 0 { os.Exit(7); }

    // Rejection: the unoptimised level carrying a transformation.
    mut optimised_baseline := decision("none", "constant_folding", "compiler", 0, 1, &ctx);
    mut baseline_bad := target.mir_optimisation_decision_validate(optimised_baseline, &ctx);
    if baseline_bad.valid == 1 || std.str_eq(baseline_bad.reason_code, "optimisation_level_transformation_undeclared") == 0 { os.Exit(8); }

    // Rejection: a level the backend selected rather than the compiler.
    mut backend_chosen := decision("basic", "dead_code_elimination", "backend", 0, 1, &ctx);
    mut backend_validation := target.mir_optimisation_decision_validate(backend_chosen, &ctx);
    if backend_validation.valid == 1 || std.str_eq(backend_validation.reason_code, "optimisation_level_selected_by_backend") == 0 { os.Exit(9); }

    // Rejection: a level that changed observable behaviour.
    mut behaviour_changed := decision("basic", "dead_code_elimination", "compiler", 1, 1, &ctx);
    mut behaviour_validation := target.mir_optimisation_decision_validate(behaviour_changed, &ctx);
    if behaviour_validation.valid == 1 || std.str_eq(behaviour_validation.reason_code, "optimisation_level_changed_observable_behaviour") == 0 { os.Exit(10); }


    // Rejection: an optimised build whose transformation did not preserve the
    // line table the debug plan promises.
    mut unpreserved := decision("basic", "dead_code_elimination", "compiler", 0, 0, &ctx);
    mut unpreserved_validation := target.mir_optimisation_debug_compatible(unpreserved, "line_tables_only", &ctx);
    if unpreserved_validation.valid == 1 || std.str_eq(unpreserved_validation.reason_code, "optimisation_level_incompatible_with_debug_plan") == 0 { os.Exit(11); }

    // Sentinel: the unoptimised level is compatible even without preservation,
    // proving the refusal came from the transformation and not from the level.
    mut untouched := decision("none", "", "compiler", 0, 0, &ctx);
    if target.mir_optimisation_debug_compatible(untouched, "line_tables_only", &ctx).valid == 0 { os.Exit(12); }

    os.LogStr("SUCCESS: Phase 18.14 optimisation level smoke passed");
}
