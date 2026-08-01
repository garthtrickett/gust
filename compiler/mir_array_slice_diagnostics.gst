// Phase 14.8 stable diagnostics for fixed arrays and bounded slices.

import "mir_array_slice.gst" as array_slice;

func mir_array_slice_diagnostic_for_rejection(kind: str, source: str, line: int, column: int, ctx: &Arena) str {
    mut rejection := array_slice.mir_array_slice_rejection(kind, ctx);
    mut output := "gust_array_slice_diagnostic: taxonomy=gust.array_slice.diagnostic.v1 reason_code=";
    output = std.Concat(output, rejection.reason_code);
    output = std.Concat(output, " source=");
    output = std.Concat(output, source);
    output = std.Concat(output, " line=");
    output = std.Concat(output, std.FormatInt(line));
    output = std.Concat(output, " column=");
    output = std.Concat(output, std.FormatInt(column));
    output = std.Concat(output, " operation=");
    output = std.Concat(output, kind);
    output = std.Concat(output, " detail=compiler-owned array or bounded-slice validation failed");
    return std.Clone(ctx, output);
}