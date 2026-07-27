import "mir_layout.gst" as layout;

// Runtime-facing descriptors are rendered from the compiler decision rather
// than from duplicated runtime offsets or host-language sizeof guesses.
func mir_layout_runtime_descriptor(table: layout.MirLayoutTable[ctx], type_id: str, target_id: str, ctx: &Arena) str {
    mut result := layout.mir_layout_of(table, type_id, target_id, ctx);
    if result.found == 0 {
        return std.Clone(ctx, "layout_descriptor: unavailable");
    }
    mut descriptor := "layout_descriptor: type=";
    descriptor = std.Concat(descriptor, result.layout.type_id);
    descriptor = std.Concat(descriptor, " layout=");
    descriptor = std.Concat(descriptor, result.layout.layout_id);
    descriptor = std.Concat(descriptor, " size=");
    descriptor = std.Concat(descriptor, std.FormatInt(result.layout.size));
    descriptor = std.Concat(descriptor, " alignment=");
    descriptor = std.Concat(descriptor, std.FormatInt(result.layout.alignment));
    descriptor = std.Concat(descriptor, " stride=");
    descriptor = std.Concat(descriptor, std.FormatInt(result.layout.element_stride));
    return std.Clone(ctx, descriptor);
}