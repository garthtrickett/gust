import "mir_destructor_scheduling.gst" as scheduling;

func fail(message: str) {
    os.LogStr(message);
    os.Exit(1);
}

func make_entry(resource_id: str, destructor_id: str, cleanup_reason: str, declaration_id: str, source_location: str, schedule_id: str, cancel_id: str, execute_id: str, mark_id: str, schedule_point: str, cancel_point: str, execution_point: str, mark_point: str, schedule_sequence: int, cancel_sequence: int, execution_sequence: int, mark_sequence: int, schedule_count: int, cancel_count: int, execution_count: int, execution_order: int, ownership_state: str, canceled_for_transfer: int, effect: str, ctx: &Arena) scheduling.MirDestructorScheduleEntry[ctx] {
    mut entry: scheduling.MirDestructorScheduleEntry[ctx];
    entry.resource_id = std.Clone(ctx, resource_id);
    entry.destructor_id = std.Clone(ctx, destructor_id);
    entry.execution_destructor_id = std.Clone(ctx, destructor_id);
    entry.cleanup_reason = std.Clone(ctx, cleanup_reason);
    entry.owning_declaration = std.Clone(ctx, declaration_id);
    entry.source_location = std.Clone(ctx, source_location);
    entry.schedule_operation_id = std.Clone(ctx, schedule_id);
    entry.cancel_operation_id = std.Clone(ctx, cancel_id);
    entry.execute_operation_id = std.Clone(ctx, execute_id);
    entry.mark_destroyed_operation_id = std.Clone(ctx, mark_id);
    entry.schedule_point = std.Clone(ctx, schedule_point);
    entry.cancel_point = std.Clone(ctx, cancel_point);
    entry.execution_point = std.Clone(ctx, execution_point);
    entry.mark_destroyed_point = std.Clone(ctx, mark_point);
    entry.schedule_sequence = schedule_sequence;
    entry.cancel_sequence = cancel_sequence;
    entry.execution_sequence = execution_sequence;
    entry.mark_destroyed_sequence = mark_sequence;
    entry.schedule_count = schedule_count;
    entry.cancel_count = cancel_count;
    entry.execution_count = execution_count;
    entry.execution_order = execution_order;
    entry.ownership_state = std.Clone(ctx, ownership_state);
    entry.canceled_for_transfer = canceled_for_transfer;
    entry.observable_effect = std.Clone(ctx, effect);
    return entry;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut plan := scheduling.mir_destructor_scheduling_make_plan(&ctx);
    plan = scheduling.mir_destructor_scheduling_with_entry(plan, make_entry("resource:scope:inner", "destructor:file", "scope_exit", "decl:inner", "compiler/destructor.gst:10:5", "operation:schedule:inner", "", "operation:execute:inner", "operation:mark:inner", "point:scope:inner:schedule", "", "point:scope:inner:execute", "point:scope:inner:mark", 10, 0, 20, 21, 1, 0, 1, 1, "live", 0, "destroy:scope:inner", &ctx), &ctx);
    plan = scheduling.mir_destructor_scheduling_with_entry(plan, make_entry("resource:scope:outer", "destructor:file", "scope_exit", "decl:outer", "compiler/destructor.gst:5:5", "operation:schedule:outer", "", "operation:execute:outer", "operation:mark:outer", "point:scope:outer:schedule", "", "point:scope:outer:execute", "point:scope:outer:mark", 11, 0, 30, 31, 1, 0, 1, 2, "live", 0, "destroy:scope:outer", &ctx), &ctx);
    plan = scheduling.mir_destructor_scheduling_with_entry(plan, make_entry("resource:early:return", "destructor:socket", "early_return", "decl:return", "compiler/destructor.gst:20:9", "operation:schedule:return", "", "operation:execute:return", "operation:mark:return", "point:return:schedule", "", "point:return:execute", "point:return:mark", 12, 0, 40, 41, 1, 0, 1, 3, "live", 0, "destroy:early:return", &ctx), &ctx);
    plan = scheduling.mir_destructor_scheduling_with_entry(plan, make_entry("resource:transferred", "destructor:socket", "ownership_transfer", "decl:transfer", "compiler/destructor.gst:30:5", "operation:schedule:transfer", "operation:cancel:transfer", "", "", "point:transfer:schedule", "point:transfer:cancel", "", "", 13, 14, 0, 0, 1, 1, 0, 0, "moved", 1, "cancel:ownership:transferred", &ctx), &ctx);

    mut validation := scheduling.mir_destructor_scheduling_validate(plan, &ctx);
    if validation.valid == 0 {
        fail(std.Concat("Phase 15.7 plan rejected: ", validation.reason_code));
    }
    mut request := scheduling.mir_destructor_scheduling_append_to_request("", plan, &ctx);
    mut witness := scheduling.mir_destructor_scheduling_mir_to_c_witness(plan, &ctx);
    if os.WriteFile("/tmp/gust-phase15-destructor-scheduling.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase15-destructor-scheduling.mir-to-c.witness", witness) == 0
    {
        fail("Phase 15.7 artifacts could not be written");
    }
    os.LogStr("SUCCESS: Phase 15.7 destructor scheduling parity smoke passed");
}
