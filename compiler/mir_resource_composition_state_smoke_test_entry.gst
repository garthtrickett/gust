import "mir_resource_authority.gst" as authority;
import "mir_resource_composition.gst" as composition;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut table := authority.mir_resource_make_empty_table("x86_64-linux-gnu", "x86_64-unknown-linux-gnu", &ctx);

    mut coverage := composition.mir_resource_composition_make_plan(&ctx);
    coverage.covered_entry_ids = std.Clone(ctx, "p15_directory_resources");
    mut coverage_result := composition.mir_resource_composition_validate(coverage, table, &ctx);
    if coverage_result.valid == 1 || std.str_eq(coverage_result.reason_code, "resource_composition_coverage_mismatch") == 0 { os.Exit(1); }

    mut backend := composition.mir_resource_composition_make_plan(&ctx);
    backend.backend_policy = std.Clone(ctx, "backend_local_resource_planner");
    mut backend_result := composition.mir_resource_composition_validate(backend, table, &ctx);
    if backend_result.valid == 1 || std.str_eq(backend_result.reason_code, "resource_composition_authority_mismatch") == 0 { os.Exit(1); }

    os.LogStr("SUCCESS: Phase 15.13 resource composition state policy passed");
}
