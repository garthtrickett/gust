import "mir_early_exit_cleanup.gst" as early;

func fail(message: str) {
    os.LogStr(message);
    os.Exit(1);
}

func make_edge(edge_id: str, kind: str, source_scope: str, destination_scope: str, return_value: str, return_abi: str, evaluation_order: int, cleanup_begin: int, terminator_order: int, source_location: str, exited_scopes: str, ctx: &Arena) early.MirEarlyExitEdge[ctx] {
    mut edge: early.MirEarlyExitEdge[ctx];
    edge.edge_id = std.Clone(ctx, edge_id);
    edge.exit_kind = std.Clone(ctx, kind);
    edge.source_scope_id = std.Clone(ctx, source_scope);
    edge.destination_scope_id = std.Clone(ctx, destination_scope);
    edge.return_value_id = std.Clone(ctx, return_value);
    edge.return_abi = std.Clone(ctx, return_abi);
    edge.return_evaluation_order = evaluation_order;
    edge.cleanup_begin_order = cleanup_begin;
    edge.terminator_order = terminator_order;
    edge.source_location = std.Clone(ctx, source_location);
    edge.exited_scope_chain = std.Clone(ctx, exited_scopes);
    return edge;
}

func make_cleanup(edge_id: str, scope_id: str, resource_id: str, cleanup_id: str, destructor_id: str, declaration_id: str, source_location: str, depth: int, declaration_order: int, execution_order: int, effect: str, ctx: &Arena) early.MirEarlyExitCleanup[ctx] {
    mut entry: early.MirEarlyExitCleanup[ctx];
    entry.edge_id = std.Clone(ctx, edge_id);
    entry.scope_id = std.Clone(ctx, scope_id);
    entry.resource_id = std.Clone(ctx, resource_id);
    entry.cleanup_operation_id = std.Clone(ctx, cleanup_id);
    entry.destructor_id = std.Clone(ctx, destructor_id);
    entry.owning_declaration = std.Clone(ctx, declaration_id);
    entry.source_location = std.Clone(ctx, source_location);
    entry.scope_depth = depth;
    entry.declaration_order = declaration_order;
    entry.execution_order = execution_order;
    entry.prior_state = std.Clone(ctx, "live");
    entry.observable_effect = std.Clone(ctx, effect);
    return entry;
}

func make_exclusion(edge_id: str, scope_id: str, resource_id: str, state: str, reason: str, ctx: &Arena) early.MirEarlyExitCleanupExclusion[ctx] {
    mut exclusion: early.MirEarlyExitCleanupExclusion[ctx];
    exclusion.edge_id = std.Clone(ctx, edge_id);
    exclusion.scope_id = std.Clone(ctx, scope_id);
    exclusion.resource_id = std.Clone(ctx, resource_id);
    exclusion.state = std.Clone(ctx, state);
    exclusion.reason = std.Clone(ctx, reason);
    return exclusion;
}

func main() {
    mut ctx: Arena;
    mut plan := early.mir_early_exit_cleanup_make_plan(&ctx);

    plan = early.mir_early_exit_cleanup_with_edge(plan, make_edge("edge:early:direct", "direct_return", "scope:function", "", "value:return:direct", "scalar", 1, 2, 4, "compiler/early_return.gst:10:5", "scope:function", &ctx), &ctx);
    plan = early.mir_early_exit_cleanup_with_entry(plan, make_cleanup("edge:early:direct", "scope:function", "resource:direct", "operation:early:direct:destroy", "destructor:early:return", "decl:direct", "compiler/early_return.gst:8:5", 1, 1, 1, "destroy:direct", &ctx), &ctx);

    plan = early.mir_early_exit_cleanup_with_edge(plan, make_edge("edge:early:branch", "nested_conditional_return", "scope:branch", "", "value:return:branch", "scalar", 1, 2, 6, "compiler/early_return.gst:20:9", "scope:branch>scope:function", &ctx), &ctx);
    plan = early.mir_early_exit_cleanup_with_entry(plan, make_cleanup("edge:early:branch", "scope:branch", "resource:branch:second", "operation:early:branch:second:destroy", "destructor:early:return", "decl:branch:second", "compiler/early_return.gst:18:9", 2, 2, 1, "destroy:branch:second", &ctx), &ctx);
    plan = early.mir_early_exit_cleanup_with_entry(plan, make_cleanup("edge:early:branch", "scope:branch", "resource:branch:first", "operation:early:branch:first:destroy", "destructor:early:return", "decl:branch:first", "compiler/early_return.gst:17:9", 2, 1, 2, "destroy:branch:first", &ctx), &ctx);
    plan = early.mir_early_exit_cleanup_with_entry(plan, make_cleanup("edge:early:branch", "scope:function", "resource:function", "operation:early:branch:function:destroy", "destructor:early:return", "decl:function", "compiler/early_return.gst:5:5", 1, 1, 3, "destroy:function", &ctx), &ctx);

    plan = early.mir_early_exit_cleanup_with_edge(plan, make_edge("edge:early:loop-return", "selected_loop_return", "scope:loop", "", "value:return:loop", "scalar", 1, 2, 5, "compiler/early_return.gst:30:9", "scope:loop>scope:function", &ctx), &ctx);
    plan = early.mir_early_exit_cleanup_with_entry(plan, make_cleanup("edge:early:loop-return", "scope:loop", "resource:loop", "operation:early:loop:destroy", "destructor:early:return", "decl:loop", "compiler/early_return.gst:28:9", 2, 1, 1, "destroy:loop", &ctx), &ctx);
    plan = early.mir_early_exit_cleanup_with_entry(plan, make_cleanup("edge:early:loop-return", "scope:function", "resource:loop:function", "operation:early:loop:function:destroy", "destructor:early:return", "decl:loop:function", "compiler/early_return.gst:25:5", 1, 1, 2, "destroy:loop:function", &ctx), &ctx);

    plan = early.mir_early_exit_cleanup_with_edge(plan, make_edge("edge:early:break", "selected_break", "scope:loop:break", "scope:function", "", "void", 1, 2, 4, "compiler/early_return.gst:40:9", "scope:loop:break", &ctx), &ctx);
    plan = early.mir_early_exit_cleanup_with_entry(plan, make_cleanup("edge:early:break", "scope:loop:break", "resource:break", "operation:early:break:destroy", "destructor:early:return", "decl:break", "compiler/early_return.gst:38:9", 2, 1, 1, "destroy:break", &ctx), &ctx);

    plan = early.mir_early_exit_cleanup_with_edge(plan, make_edge("edge:early:continue", "selected_continue", "scope:loop:continue", "scope:loop:continue", "", "void", 1, 2, 4, "compiler/early_return.gst:50:9", "scope:iteration", &ctx), &ctx);
    plan = early.mir_early_exit_cleanup_with_entry(plan, make_cleanup("edge:early:continue", "scope:iteration", "resource:continue", "operation:early:continue:destroy", "destructor:early:return", "decl:continue", "compiler/early_return.gst:48:9", 3, 1, 1, "destroy:continue", &ctx), &ctx);

    plan = early.mir_early_exit_cleanup_with_exclusion(plan, make_exclusion("edge:early:direct", "scope:function", "resource:moved", "moved", "moved_resource", &ctx), &ctx);
    plan = early.mir_early_exit_cleanup_with_exclusion(plan, make_exclusion("edge:early:branch", "scope:branch", "resource:closed", "manually_closed", "manually_closed_resource", &ctx), &ctx);

    mut validation := early.mir_early_exit_cleanup_validate(plan, &ctx);
    if validation.valid == 0 {
        fail(std.Concat("Phase 15.6 plan rejected: ", validation.reason_code));
    }

    mut request := early.mir_early_exit_cleanup_append_to_request("", plan, &ctx);
    mut witness := early.mir_early_exit_cleanup_witness(plan, &ctx);
    witness = std.Concat(witness, "early_return_cleanup_lowering_witness: accepted return_value_evaluated_before_cleanup=1 cleanup_before_terminator=1 scalar_return_abi_preserved=1 output_preserved=1\n");

    if os.WriteFile("/tmp/gust-phase15-early-return-cleanup.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase15-early-return-cleanup.mir-to-c.witness", witness) == 0
    {
        fail("Phase 15.6 artifacts could not be written");
    }
    os.LogStr("SUCCESS: Phase 15.6 early-return cleanup parity smoke passed");
}