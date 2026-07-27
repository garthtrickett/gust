import "mir_layout.gst" as layout;

// MIR-to-C consumes compiler-owned layout records through this adapter.
// It may verify emitted C storage later, but it must not choose layout here.
func mir_layout_for_mir_to_c(table: layout.MirLayoutTable[ctx], type_id: str, target_id: str, ctx: &Arena) layout.MirTypeLayoutQuery[ctx] {
    return layout.mir_layout_of(table, type_id, target_id, ctx);
}