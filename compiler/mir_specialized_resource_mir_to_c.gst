// Patch 15.11 MIR-to-C consumer. It consumes the compiler-owned specialized
// kind mapping and the generic resource authority; it does not infer state.
import "mir_resource_authority.gst" as authority;
import "mir_specialized_resource.gst" as specialized;

func mir_specialized_resource_mir_to_c_lower(plan: specialized.MirSpecializedResourcePlan[ctx], table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    return std.Clone(ctx, specialized.mir_specialized_resource_witness(plan, table, ctx));
}
