import "mir_resource_authority.gst" as authority;
import "mir_resource_composition.gst" as composition;

func mir_resource_composition_mir_to_c_lower(plan: composition.MirResourceCompositionPlan[ctx], table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    return std.Clone(ctx, composition.mir_resource_composition_witness(plan, table, ctx));
}
