// Phase 14.7 stable diagnostics for string literals and borrowed views.

import "mir_string_view.gst" as string_view;

type MirStringViewDiagnostic[ctx] struct {
    taxonomy: str,
    reason_code: str,
    source: str,
    line: int,
    column: int,
    operation_kind: str,
    detail: str
}

func mir_string_view_make_diagnostic(reason_code: str, source: str, line: int, column: int, operation_kind: str, detail: str, ctx: &Arena) MirStringViewDiagnostic[ctx] {
    mut diagnostic: MirStringViewDiagnostic[ctx];
    diagnostic.taxonomy = std.Clone(ctx, "gust.string_view.diagnostic.v1");
    diagnostic.reason_code = std.Clone(ctx, reason_code);
    diagnostic.source = std.Clone(ctx, source);
    diagnostic.line = line;
    diagnostic.column = column;
    diagnostic.operation_kind = std.Clone(ctx, operation_kind);
    diagnostic.detail = std.Clone(ctx, detail);
    return diagnostic;
}

func mir_string_view_diagnostic_text(diagnostic: MirStringViewDiagnostic[ctx], ctx: &Arena) str {
    mut output := "gust_string_view_diagnostic: taxonomy=gust.string_view.diagnostic.v1 reason_code=";
    output = std.Concat(output, diagnostic.reason_code);
    output = std.Concat(output, " source=");
    output = std.Concat(output, diagnostic.source);
    output = std.Concat(output, " line=");
    output = std.Concat(output, std.FormatInt(diagnostic.line));
    output = std.Concat(output, " column=");
    output = std.Concat(output, std.FormatInt(diagnostic.column));
    output = std.Concat(output, " operation=");
    output = std.Concat(output, diagnostic.operation_kind);
    output = std.Concat(output, " detail=");
    output = std.Concat(output, diagnostic.detail);
    return std.Clone(ctx, output);
}

func mir_string_view_diagnostic_for_rejection(kind: str, source: str, line: int, column: int, ctx: &Arena) str {
    mut rejection := string_view.mir_string_view_rejection(kind, ctx);
    mut diagnostic := mir_string_view_make_diagnostic(
        rejection.reason_code,
        source,
        line,
        column,
        kind,
        "compiler-owned string literal or borrowed-view validation failed",
        ctx
    );
    return mir_string_view_diagnostic_text(diagnostic, ctx);
}