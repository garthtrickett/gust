import "mir_layout.gst" as layout;
import "mir_primitive_layout.gst" as primitive;

// MIR-to-C consumes compiler-owned layout records through this adapter.
// It may verify emitted C storage later, but it must not choose layout here.
func mir_layout_for_mir_to_c(table: layout.MirLayoutTable[ctx], type_id: str, target_id: str, ctx: &Arena) layout.MirTypeLayoutQuery[ctx] {
    return layout.mir_layout_of(table, type_id, target_id, ctx);
}

// Emit verification C from compiler-selected primitive records. The C host
// validates the decision with static assertions; it does not select layout.
func mir_layout_primitive_witness_c_source(table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    return primitive.mir_primitive_layout_c_witness_source(table, ctx);
}
