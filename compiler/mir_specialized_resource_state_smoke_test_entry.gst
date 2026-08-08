import "mir_resource_authority.gst" as authority;
import "mir_specialized_resource.gst" as specialized;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut table_state := authority.mir_resource_make_empty_table("x86_64-linux-gnu", "x86_64-unknown-linux-gnu", &ctx);

    mut inventory_plan := specialized.mir_specialized_resource_make_directory_plan(&ctx);
    inventory_plan.selected_kinds = std.Clone(ctx, "os_Dir_ctx,os_DirEntry_ctx");
    mut inventory_result := specialized.mir_specialized_resource_validate(inventory_plan, table_state, &ctx);
    if inventory_result.valid == 1 || std.str_eq(inventory_result.reason_code, "specialized_resource_inventory_unfrozen") == 0 { os.Exit(1); }

    mut kind_plan := specialized.mir_specialized_resource_make_directory_plan(&ctx);
    kind_plan.kind.move_policy = std.Clone(ctx, "backend_defined");
    mut kind_result := specialized.mir_specialized_resource_validate(kind_plan, table_state, &ctx);
    if kind_result.valid == 1 || std.str_eq(kind_result.reason_code, "specialized_resource_kind_contract_mismatch") == 0 { os.Exit(1); }

    os.LogStr("SUCCESS: Phase 15.11 specialized resource state policy passed");
}
