// Stable Phase 14.6 typed memory-access diagnostic taxonomy.
func mir_memory_access_diagnostic(reason_code: str, operation: str, accessed_type: str, layout_id: str, byte_width: int, required_alignment: int, origin: str, mutability: str, source: str, line: int, column: int, ctx: &Arena) str {
    mut output := "gust_memory_access_diagnostic: taxonomy=gust.memory_access.diagnostic.v1 reason_code=";
    output = std.Concat(output, reason_code);
    output = std.Concat(output, " operation="); output = std.Concat(output, operation);
    output = std.Concat(output, " accessed_type="); output = std.Concat(output, accessed_type);
    output = std.Concat(output, " layout_id="); output = std.Concat(output, layout_id);
    output = std.Concat(output, " byte_width="); output = std.Concat(output, std.FormatInt(byte_width));
    output = std.Concat(output, " required_alignment="); output = std.Concat(output, std.FormatInt(required_alignment));
    output = std.Concat(output, " origin="); output = std.Concat(output, origin);
    output = std.Concat(output, " mutability="); output = std.Concat(output, mutability);
    output = std.Concat(output, " source="); output = std.Concat(output, source);
    output = std.Concat(output, " line="); output = std.Concat(output, std.FormatInt(line));
    output = std.Concat(output, " column="); output = std.Concat(output, std.FormatInt(column));
    output = std.Concat(output, "\n");
    return std.Clone(ctx, output);
}