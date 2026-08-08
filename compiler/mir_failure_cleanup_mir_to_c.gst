// Patch 15.12 MIR-to-C consumer. Cleanup state and ordering are read from the
// compiler-owned plan and generic resource authority.
import "mir_resource_authority.gst" as authority;
import "mir_failure_cleanup.gst" as failure;

func mir_failure_cleanup_mir_to_c_lower(plan: failure.MirFailureCleanupPlan[ctx], table: authority.MirResourceAuthorityTable[ctx], ctx: &Arena) str {
    return std.Clone(ctx, failure.mir_failure_cleanup_witness(plan, table, ctx));
}
