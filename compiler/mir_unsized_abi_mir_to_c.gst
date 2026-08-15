import "mir_unsized_abi.gst" as unsized;
import "mir_layout.gst" as layout;
func mir_unsized_abi_mir_to_c_witness(table: unsized.MirUnsizedAbiTable[ctx], layouts: layout.MirLayoutTable[ctx], ctx: &Arena) str { return std.Clone(ctx, unsized.mir_serialize_unsized_abi_for_request(table, layouts, ctx)); }
