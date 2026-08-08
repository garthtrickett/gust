import "mir_resource_authority.gst" as authority;
import "mir_resource_composition.gst" as composition;
import "mir_resource_composition_mir_to_c.gst" as composition_c;

func fail(message: str) { os.LogStr(message); os.Exit(1); }

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut table := authority.mir_resource_make_empty_table("x86_64-linux-gnu", "x86_64-unknown-linux-gnu", &ctx);
    mut resource: authority.MirResourceIdentity[ctx];
    resource.resource_id = std.Clone(ctx, "resource:composition:root");
    resource.value_id = std.Clone(ctx, "value:composition:root");
    resource.resource_type_id = std.Clone(ctx, "Phase15ComposedResource");
    resource.source_declaration_id = std.Clone(ctx, "decl:composition:root");
    resource.source_location = std.Clone(ctx, "compiler/future/p15_complete_resource_differential_source.gst:5:5");
    resource.owning_function = std.Clone(ctx, "composed_resource_status");
    resource.owning_scope = std.Clone(ctx, "scope:composed_resource_status");
    resource.resource_kind = std.Clone(ctx, "composition_root");
    resource.destructor_id = std.Clone(ctx, "destructor:composition:root");
    resource.close_capability_id = std.Clone(ctx, "close:composition:root");
    resource.copy_policy = std.Clone(ctx, "prohibited");
    resource.move_policy = std.Clone(ctx, "move_only");
    resource.cleanup_policy = std.Clone(ctx, "compiler_owned_exactly_once");
    resource.target_id = std.Clone(ctx, "x86_64-linux-gnu");
    resource.target_triple = std.Clone(ctx, "x86_64-unknown-linux-gnu");
    resource.layout_id = std.Clone(ctx, "layout:composition:root");
    table = authority.mir_resource_table_with_resource(table, resource, &ctx);

    mut plan := composition.mir_resource_composition_make_plan(&ctx);
    mut validation := composition.mir_resource_composition_validate(plan, table, &ctx);
    if validation.valid == 0 { fail(std.Concat("Phase 15.13 composition rejected: ", validation.reason_code)); }
    mut request := composition.mir_resource_composition_append_to_request("", plan, table, &ctx);
    mut witness := composition_c.mir_resource_composition_mir_to_c_lower(plan, table, &ctx);
    if std.str_find(witness, "covered_entries=12") == 0 - 1 ||
       std.str_find(witness, "mir_to_c_cranelift_witness_identity=1") == 0 - 1
    { fail("Phase 15.13 composition witness drifted"); }
    if os.WriteFile("/tmp/gust-phase15-resource-composition.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase15-resource-composition.mir-to-c.witness", witness) == 0
    { fail("Phase 15.13 composition artifacts could not be written"); }
    os.LogStr("SUCCESS: Phase 15.13 resource composition parity smoke passed");
}
