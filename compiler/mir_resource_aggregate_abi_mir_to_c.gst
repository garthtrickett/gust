import "mir_resource_aggregate_abi.gst" as resource_aggregate;
import "mir_layout.gst" as layout;
func mir_resource_aggregate_abi_mir_to_c_witness(table: resource_aggregate.MirResourceAggregateAbiTable[ctx], layouts: layout.MirLayoutTable[ctx], ctx: &Arena) str { return std.Clone(ctx,resource_aggregate.mir_serialize_resource_aggregate_abi_for_request(table,layouts,ctx)); }
