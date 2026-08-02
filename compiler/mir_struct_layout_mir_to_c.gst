// Phase 14.9 MIR-to-C evidence for compiler-owned struct layout.
//
// Two independent checks run here. Declared C structs assert the compiler's
// size, alignment, and field offsets at C compile time, and byte-level loads
// and stores execute against those same compiler-owned offsets at run time.

import "mir_layout.gst" as layout;
import "mir_struct_layout.gst" as structs;

func mir_struct_c_escape(value: str, ctx: &Arena) str {
    mut output := "";
    mut index := 0;
    while index < len(value) {
        mut byte := std.str_byte_at(value, index);
        if byte == 92 { output = std.Concat(output, "\\\\"); }
        else if byte == 34 { output = std.Concat(output, "\\\""); }
        else if byte == 10 { output = std.Concat(output, "\\n"); }
        else if byte == 13 { output = std.Concat(output, "\\r"); }
        else { output = std.Concat(output, std.str_slice(value, index, index + 1)); }
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_struct_c_layout_index(table: structs.MirStructTable[ctx], layout_id: str, ctx: &Arena) int {
    mut layouts: std.Vector[structs.MirStructLayout[ctx], ctx] := ctx[table.layouts];
    mut index := 0;
    while index < len(layouts) {
        if std.str_eq(layouts[index].layout_id, layout_id) == 1 { return index; }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_struct_c_value_index(table: structs.MirStructTable[ctx], value_id: str, ctx: &Arena) int {
    mut values: std.Vector[structs.MirStructValue[ctx], ctx] := ctx[table.values];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].value_id, value_id) == 1 { return index; }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_struct_c_layout_name(index: int, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat("GustStruct", std.FormatInt(index)));
}

func mir_struct_c_value_name(index: int, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat("gust_struct_value_", std.FormatInt(index)));
}

func mir_struct_c_scalar_type(type_id: str) str {
    if std.str_eq(type_id, "type:gust:u8") == 1 { return "uint8_t"; }
    if std.str_eq(type_id, "type:gust:i32") == 1 { return "int32_t"; }
    return "int64_t";
}

func mir_struct_c_width(type_id: str) int {
    if std.str_eq(type_id, "type:gust:u8") == 1 { return 1; }
    if std.str_eq(type_id, "type:gust:i32") == 1 { return 4; }
    return 8;
}

func mir_struct_c_source(table: structs.MirStructTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if structs.mir_struct_table_is_valid(table, layout_table, ctx) == 0 ||
       structs.mir_struct_table_is_legacy_empty(table, ctx) == 1
    {
        return "";
    }

    mut output := "#include <stddef.h>\n#include <stdint.h>\n#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n\n";
    output = std.Concat(output, "static int64_t gust_field_read(const unsigned char *base, size_t offset, size_t width) {\n");
    output = std.Concat(output, "    int64_t value = 0;\n");
    output = std.Concat(output, "    memcpy(&value, base + offset, width);\n");
    output = std.Concat(output, "    return value;\n");
    output = std.Concat(output, "}\n");
    output = std.Concat(output, "static void gust_field_write(unsigned char *base, size_t offset, size_t width, int64_t value) {\n");
    output = std.Concat(output, "    memcpy(base + offset, &value, width);\n");
    output = std.Concat(output, "}\n\n");

    // Declared C structs prove the compiler-owned offsets, padding, size, and
    // alignment agree with the platform layout for the selected inventory.
    mut layouts: std.Vector[structs.MirStructLayout[ctx], ctx] := ctx[table.layouts];
    mut layout_index := 0;
    while layout_index < len(layouts) {
        mut value := layouts[layout_index];
        mut struct_name := mir_struct_c_layout_name(layout_index, ctx);
        mut fields: std.Vector[structs.MirStructField[ctx], ctx] := ctx[value.fields];
        output = std.Concat(output, "typedef struct {");
        mut field_index := 0;
        while field_index < len(fields) {
            mut field := fields[field_index];
            output = std.Concat(output, " ");
            if field.is_aggregate == 1 {
                output = std.Concat(output, mir_struct_c_layout_name(mir_struct_c_layout_index(table, field.layout_id, ctx), ctx));
            } else {
                output = std.Concat(output, mir_struct_c_scalar_type(field.type_id));
            }
            output = std.Concat(output, " f");
            output = std.Concat(output, std.FormatInt(field_index));
            output = std.Concat(output, ";");
            field_index = field_index + 1;
        }
        output = std.Concat(output, " } ");
        output = std.Concat(output, struct_name);
        output = std.Concat(output, ";\n");

        output = std.Concat(output, "_Static_assert(sizeof(");
        output = std.Concat(output, struct_name);
        output = std.Concat(output, ") == ");
        output = std.Concat(output, std.FormatInt(value.size));
        output = std.Concat(output, ", \"compiler-selected struct size mismatch\");\n");
        output = std.Concat(output, "_Static_assert(_Alignof(");
        output = std.Concat(output, struct_name);
        output = std.Concat(output, ") == ");
        output = std.Concat(output, std.FormatInt(value.alignment));
        output = std.Concat(output, ", \"compiler-selected struct alignment mismatch\");\n");
        field_index = 0;
        while field_index < len(fields) {
            output = std.Concat(output, "_Static_assert(offsetof(");
            output = std.Concat(output, struct_name);
            output = std.Concat(output, ", f");
            output = std.Concat(output, std.FormatInt(field_index));
            output = std.Concat(output, ") == ");
            output = std.Concat(output, std.FormatInt(fields[field_index].offset));
            output = std.Concat(output, ", \"compiler-selected field offset mismatch\");\n");
            field_index = field_index + 1;
        }
        layout_index = layout_index + 1;
    }

    output = std.Concat(output, "\n");
    mut values: std.Vector[structs.MirStructValue[ctx], ctx] := ctx[table.values];
    mut value_index := 0;
    while value_index < len(values) {
        mut value := values[value_index];
        mut layout_query := structs.mir_struct_layout(table, value.layout_id, ctx);
        output = std.Concat(output, "static unsigned char ");
        output = std.Concat(output, mir_struct_c_value_name(value_index, ctx));
        output = std.Concat(output, "[");
        output = std.Concat(output, std.FormatInt(layout_query.value.size));
        output = std.Concat(output, "];\n");
        value_index = value_index + 1;
    }

    output = std.Concat(output, "\nint main(void) {\n");

    // Materialize each struct value through its compiler-owned leaf offsets.
    value_index = 0;
    while value_index < len(values) {
        mut value := values[value_index];
        mut leaves: std.Vector[structs.MirStructLeaf[ctx], ctx] := ctx[structs.mir_struct_leaves(table, value.layout_id, ctx)];
        mut scalars: std.Vector[int, ctx] := ctx[value.scalar_values];
        mut leaf_index := 0;
        while leaf_index < len(leaves) {
            output = std.Concat(output, "    gust_field_write(");
            output = std.Concat(output, mir_struct_c_value_name(value_index, ctx));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(leaves[leaf_index].offset));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(mir_struct_c_width(leaves[leaf_index].type_id)));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(scalars[leaf_index]));
            output = std.Concat(output, ");\n");
            leaf_index = leaf_index + 1;
        }
        value_index = value_index + 1;
    }

    mut operations: std.Vector[structs.MirStructOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        mut target_index := mir_struct_c_value_index(table, operation.value_id, ctx);
        mut value := values[target_index];
        mut layout_query := structs.mir_struct_layout(table, value.layout_id, ctx);
        mut buffer := mir_struct_c_value_name(target_index, ctx);
        mut struct_name := mir_struct_c_layout_name(mir_struct_c_layout_index(table, value.layout_id, ctx), ctx);

        if std.str_eq(operation.kind, "construct") == 1 {
            output = std.Concat(output, "    if (sizeof(");
            output = std.Concat(output, struct_name);
            output = std.Concat(output, ") != ");
            output = std.Concat(output, std.FormatInt(layout_query.value.size));
            output = std.Concat(output, ") return 70;\n");
            output = std.Concat(output, "    if (");
            output = std.Concat(output, std.FormatInt(layout_query.value.field_count));
            output = std.Concat(output, " != ");
            output = std.Concat(output, std.FormatInt(operation.expected_value));
            output = std.Concat(output, ") return 71;\n");
        }

        if std.str_eq(operation.kind, "field_address") == 1 {
            mut field_query := structs.mir_struct_resolve_field_path(table, value.layout_id, operation.field_path, ctx);
            output = std.Concat(output, "    if ((long long)(");
            output = std.Concat(output, std.FormatInt(field_query.value.offset));
            output = std.Concat(output, ") != ");
            output = std.Concat(output, std.FormatInt(operation.expected_offset));
            output = std.Concat(output, ") return 72;\n");
        }

        if std.str_eq(operation.kind, "field_load") == 1 ||
           std.str_eq(operation.kind, "field_store") == 1
        {
            mut field_query := structs.mir_struct_resolve_field_path(table, value.layout_id, operation.field_path, ctx);
            mut width := mir_struct_c_width(field_query.value.type_id);
            if std.str_eq(operation.kind, "field_store") == 1 {
                output = std.Concat(output, "    gust_field_write(");
                output = std.Concat(output, buffer);
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(field_query.value.offset));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(width));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(operation.stored_value));
                output = std.Concat(output, ");\n");
            }
            output = std.Concat(output, "    if (gust_field_read(");
            output = std.Concat(output, buffer);
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(field_query.value.offset));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(width));
            output = std.Concat(output, ") != "); output = std.Concat(output, std.FormatInt(operation.expected_value));
            output = std.Concat(output, ") return 73;\n");
            // A field access may never leave the compiler-owned struct storage.
            output = std.Concat(output, "    if (");
            output = std.Concat(output, std.FormatInt(field_query.value.offset + width));
            output = std.Concat(output, " > "); output = std.Concat(output, std.FormatInt(layout_query.value.size));
            output = std.Concat(output, ") return 74;\n");
        }
        operation_index = operation_index + 1;
    }

    mut witness := structs.mir_struct_witness(table, layout_table, ctx);
    output = std.Concat(output, "    fputs(\"");
    output = std.Concat(output, mir_struct_c_escape(witness, ctx));
    output = std.Concat(output, "\", stdout);\n    return 0;\n}\n");
    return std.Clone(ctx, output);
}
