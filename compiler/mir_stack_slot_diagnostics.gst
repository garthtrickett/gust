// Stable Phase 14.5 stack-slot diagnostic taxonomy.
func mir_stack_slot_diagnostic(reason_code: str, source: str, line: int, column: int, ctx: &Arena) str {
    mut output := "gust_stack_slot_diagnostic: taxonomy=gust.stack_slot.diagnostic.v1 reason_code=";
    output = std.Concat(output, reason_code);
    output = std.Concat(output, " source=");
    output = std.Concat(output, source);
    output = std.Concat(output, " line=");
    output = std.Concat(output, std.FormatInt(line));
    output = std.Concat(output, " column=");
    output = std.Concat(output, std.FormatInt(column));
    output = std.Concat(output, "\n");
    return std.Clone(ctx, output);
}