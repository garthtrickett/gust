import "mir_dynamic_stack.gst" as dynamic_stack;
import "mir_layout.gst" as layout;
func mir_dynamic_stack_mir_to_c_witness(table: dynamic_stack.MirDynamicFrameTable[ctx], layouts: layout.MirLayoutTable[ctx], ctx: &Arena) str { return std.Clone(ctx, dynamic_stack.mir_serialize_dynamic_stack_for_request(table, layouts, ctx)); }
