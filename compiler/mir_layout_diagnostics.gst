import "mir_layout.gst" as layout;

// Layout diagnostics consume the same compiler-owned records as codegen.
func mir_layout_diagnostic(table: layout.MirLayoutTable[ctx], type_id: str, target_id: str, ctx: &Arena) str {
    mut result := layout.mir_layout_of(table, type_id, target_id, ctx);
    if result.found == 0 {
        mut missing := "layout_error: unknown_type_layout type=";
        missing = std.Concat(missing, type_id);
        missing = std.Concat(missing, " target=");
        missing = std.Concat(missing, target_id);
        return std.Clone(ctx, missing);
    }
    mut message := "layout: type=";
    message = std.Concat(message, result.layout.type_id);
    message = std.Concat(message, " target=");
    message = std.Concat(message, result.layout.target_id);
    message = std.Concat(message, " size=");
    message = std.Concat(message, std.FormatInt(result.layout.size));
    message = std.Concat(message, " alignment=");
    message = std.Concat(message, std.FormatInt(result.layout.alignment));
    return std.Clone(ctx, message);
}