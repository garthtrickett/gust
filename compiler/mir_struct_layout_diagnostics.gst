// Phase 14.9 stable diagnostics for declaration-order struct layout.
//
// Every rejection is reported with the compiler-owned field name and the
// compiler-owned layout decision, so a diagnostic never re-derives an offset,
// padding choice, size, or alignment from the backend.

import "mir_struct_layout.gst" as structs;

func mir_struct_diagnostic_for_rejection(table: structs.MirStructTable[ctx], kind: str, source: str, line: int, column: int, struct_layout_id: str, field_path: str, ctx: &Arena) str {
    mut rejection := structs.mir_struct_rejection(kind, ctx);
    mut output := "gust_struct_diagnostic: taxonomy=gust.struct.diagnostic.v1 reason_code=";
    output = std.Concat(output, rejection.reason_code);
    output = std.Concat(output, " source=");
    output = std.Concat(output, source);
    output = std.Concat(output, " line=");
    output = std.Concat(output, std.FormatInt(line));
    output = std.Concat(output, " column=");
    output = std.Concat(output, std.FormatInt(column));
    output = std.Concat(output, " operation=");
    output = std.Concat(output, kind);

    mut layout_query := structs.mir_struct_layout(table, struct_layout_id, ctx);
    if layout_query.found == 0 {
        output = std.Concat(output, " struct_type=unresolved struct_layout=unresolved field=");
        output = std.Concat(output, field_path);
        output = std.Concat(output, " detail=compiler-owned struct validation failed before layout resolution");
        return std.Clone(ctx, output);
    }

    mut struct_layout := layout_query.value;
    output = std.Concat(output, " struct_type=");
    output = std.Concat(output, struct_layout.struct_type_id);
    output = std.Concat(output, " struct_layout=");
    output = std.Concat(output, struct_layout.layout_id);

    // Field names and offsets are the compiler's, never a backend-invented index.
    mut field_query := structs.mir_struct_resolve_field_path(table, struct_layout_id, field_path, ctx);
    output = std.Concat(output, " field=");
    if field_query.found == 1 {
        output = std.Concat(output, field_path);
        output = std.Concat(output, " declaration_index=");
        output = std.Concat(output, std.FormatInt(field_query.value.declaration_index));
        output = std.Concat(output, " field_offset=");
        output = std.Concat(output, std.FormatInt(field_query.value.offset));
        output = std.Concat(output, " field_size=");
        output = std.Concat(output, std.FormatInt(field_query.value.size));
        output = std.Concat(output, " field_alignment=");
        output = std.Concat(output, std.FormatInt(field_query.value.alignment));
    } else {
        output = std.Concat(output, field_path);
        output = std.Concat(output, " declaration_index=-1 field_offset=-1 field_size=-1 field_alignment=-1");
    }

    output = std.Concat(output, " field_count=");
    output = std.Concat(output, std.FormatInt(struct_layout.field_count));
    output = std.Concat(output, " size=");
    output = std.Concat(output, std.FormatInt(struct_layout.size));
    output = std.Concat(output, " alignment=");
    output = std.Concat(output, std.FormatInt(struct_layout.alignment));
    output = std.Concat(output, " nesting=");
    output = std.Concat(output, std.FormatInt(struct_layout.nesting_depth));
    output = std.Concat(output, " detail=compiler-owned struct field offset or padding validation failed");
    return std.Clone(ctx, output);
}
