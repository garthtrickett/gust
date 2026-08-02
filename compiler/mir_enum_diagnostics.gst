// Phase 14.10 stable diagnostics for enums and tagged unions.
//
// Every rejection is reported with the compiler-owned variant name and the
// compiler-owned layout decision, so a diagnostic never re-derives tag width,
// tag offset, payload offset, size, or alignment from the backend.

import "mir_layout.gst" as layout;
import "mir_enum.gst" as enums;

func mir_enum_diagnostic_for_rejection(table: enums.MirEnumTable[ctx], kind: str, source: str, line: int, column: int, enum_layout_id: str, variant_name: str, ctx: &Arena) str {
    mut rejection := enums.mir_enum_rejection(kind, ctx);
    mut output := "gust_enum_diagnostic: taxonomy=gust.enum.diagnostic.v1 reason_code=";
    output = std.Concat(output, rejection.reason_code);
    output = std.Concat(output, " source=");
    output = std.Concat(output, source);
    output = std.Concat(output, " line=");
    output = std.Concat(output, std.FormatInt(line));
    output = std.Concat(output, " column=");
    output = std.Concat(output, std.FormatInt(column));
    output = std.Concat(output, " operation=");
    output = std.Concat(output, kind);

    mut layout_query := enums.mir_enum_layout_of(table, enum_layout_id, ctx);
    if layout_query.found == 0 {
        output = std.Concat(output, " enum_type=unresolved enum_layout=unresolved variant=");
        output = std.Concat(output, variant_name);
        output = std.Concat(output, " detail=compiler-owned enum validation failed before layout resolution");
        return std.Clone(ctx, output);
    }

    mut enum_layout := layout_query.enum_layout;
    output = std.Concat(output, " enum_type=");
    output = std.Concat(output, enum_layout.enum_type_id);
    output = std.Concat(output, " enum_layout=");
    output = std.Concat(output, enum_layout.layout_id);

    // Variant names are the compiler's, never a backend-invented index label.
    mut variant_query := enums.mir_enum_variant_of(enum_layout, variant_name, ctx);
    output = std.Concat(output, " variant=");
    if variant_query.found == 1 {
        output = std.Concat(output, variant_query.variant.variant_name);
        output = std.Concat(output, " declaration_index=");
        output = std.Concat(output, std.FormatInt(variant_query.variant.declaration_index));
        output = std.Concat(output, " discriminant=");
        output = std.Concat(output, std.FormatInt(variant_query.variant.discriminant));
        output = std.Concat(output, " payload_size=");
        output = std.Concat(output, std.FormatInt(variant_query.variant.payload_size));
    } else {
        output = std.Concat(output, variant_name);
        output = std.Concat(output, " declaration_index=-1 discriminant=-1 payload_size=-1");
    }

    output = std.Concat(output, " tag_type=");
    output = std.Concat(output, enum_layout.tag_type_id);
    output = std.Concat(output, " tag_width=");
    output = std.Concat(output, std.FormatInt(enum_layout.tag_width));
    output = std.Concat(output, " tag_offset=");
    output = std.Concat(output, std.FormatInt(enum_layout.tag_offset));
    output = std.Concat(output, " payload_offset=");
    output = std.Concat(output, std.FormatInt(enum_layout.payload_offset));
    output = std.Concat(output, " size=");
    output = std.Concat(output, std.FormatInt(enum_layout.size));
    output = std.Concat(output, " alignment=");
    output = std.Concat(output, std.FormatInt(enum_layout.alignment));
    output = std.Concat(output, " detail=compiler-owned enum tag or payload validation failed");
    return std.Clone(ctx, output);
}
