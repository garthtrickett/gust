// Phase 15.7 stable diagnostics for destructor scheduling and exactly-once
// destruction.

import "mir_destructor_scheduling.gst" as destructor_scheduling;

func mir_destructor_scheduling_diagnostic_for_rejection(kind: str, source: str, line: int, column: int, ctx: &Arena) str {
    mut rejection := destructor_scheduling.mir_destructor_scheduling_rejection(kind, ctx);
    mut output := "gust_destructor_scheduling_diagnostic: taxonomy=gust.destructor_scheduling.diagnostic.v1 reason_code=";
    output = std.Concat(output, rejection.reason_code);
    output = std.Concat(output, " source=");
    output = std.Concat(output, source);
    output = std.Concat(output, " line=");
    output = std.Concat(output, std.FormatInt(line));
    output = std.Concat(output, " column=");
    output = std.Concat(output, std.FormatInt(column));
    output = std.Concat(output, " operation=");
    output = std.Concat(output, kind);
    output = std.Concat(output, " detail=compiler-owned destructor scheduling or exactly-once destruction validation failed");
    return std.Clone(ctx, output);
}
