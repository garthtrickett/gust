// Phase 14.8 MIR-to-C evidence for compiler-owned arrays and bounded slices.
// Address arithmetic always uses the serialized compiler-owned stride.

import "mir_layout.gst" as layout;
import "mir_array_slice.gst" as array_slice;

func mir_array_slice_c_escape(value: str, ctx: &Arena) str {
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

func mir_array_slice_c_array_index(table: array_slice.MirArraySliceTable[ctx], array_id: str, ctx: &Arena) int {
    mut values: std.Vector[array_slice.MirArrayValue[ctx], ctx] := ctx[table.arrays];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].array_id, array_id) == 1 { return index; }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_array_slice_c_slice_index(table: array_slice.MirArraySliceTable[ctx], slice_id: str, ctx: &Arena) int {
    mut values: std.Vector[array_slice.MirSliceValue[ctx], ctx] := ctx[table.slices];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].slice_id, slice_id) == 1 { return index; }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_array_slice_c_array_name(index: int, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat("gust_array_", std.FormatInt(index)));
}

func mir_array_slice_c_slice_name(index: int, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat("gust_slice_", std.FormatInt(index)));
}

func mir_array_slice_c_width(element_type_id: str) int {
    if std.str_eq(element_type_id, "type:gust:u8") == 1 { return 1; }
    if std.str_eq(element_type_id, "type:gust:i32") == 1 { return 4; }
    return 8;
}

func mir_array_slice_c_source(table: array_slice.MirArraySliceTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if array_slice.mir_array_slice_table_is_valid(table, layout_table, ctx) == 0 ||
       array_slice.mir_array_slice_table_is_legacy_empty(table, ctx) == 1
    {
        return "";
    }

    mut output := "#include <stddef.h>\n#include <stdint.h>\n#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n\n";
    output = std.Concat(output, "typedef struct { unsigned char *data; size_t length; } GustSlice;\n");
    mut slice_layouts: std.Vector[array_slice.MirSliceLayout[ctx], ctx] := ctx[table.slice_layouts];
    mut primary_slice_layout := slice_layouts[0];
    output = std.Concat(output, "_Static_assert(sizeof(GustSlice) == ");
    output = std.Concat(output, std.FormatInt(primary_slice_layout.size));
    output = std.Concat(output, ", \"compiler-selected slice size mismatch\");\n");
    output = std.Concat(output, "_Static_assert(_Alignof(GustSlice) == ");
    output = std.Concat(output, std.FormatInt(primary_slice_layout.alignment));
    output = std.Concat(output, ", \"compiler-selected slice alignment mismatch\");\n");
    output = std.Concat(output, "_Static_assert(offsetof(GustSlice, data) == ");
    output = std.Concat(output, std.FormatInt(primary_slice_layout.data_pointer_offset));
    output = std.Concat(output, ", \"compiler-selected slice data offset mismatch\");\n");
    output = std.Concat(output, "_Static_assert(offsetof(GustSlice, length) == ");
    output = std.Concat(output, std.FormatInt(primary_slice_layout.length_offset));
    output = std.Concat(output, ", \"compiler-selected slice length offset mismatch\");\n\n");

    output = std.Concat(output, "static int64_t gust_load(const unsigned char *base, size_t index, size_t count, size_t stride, size_t width) {\n");
    output = std.Concat(output, "    int64_t value = 0;\n");
    output = std.Concat(output, "    if (index >= count) exit(80);\n");
    output = std.Concat(output, "    memcpy(&value, base + index * stride, width);\n");
    output = std.Concat(output, "    return value;\n");
    output = std.Concat(output, "}\n");
    output = std.Concat(output, "static void gust_store(unsigned char *base, size_t index, size_t count, size_t stride, size_t width, int64_t value) {\n");
    output = std.Concat(output, "    if (index >= count) exit(81);\n");
    output = std.Concat(output, "    memcpy(base + index * stride, &value, width);\n");
    output = std.Concat(output, "}\n\n");

    mut arrays: std.Vector[array_slice.MirArrayValue[ctx], ctx] := ctx[table.arrays];
    mut array_index := 0;
    while array_index < len(arrays) {
        mut value := arrays[array_index];
        mut layout_query := array_slice.mir_array_slice_array_layout(table, value.array_layout_id, ctx);
        output = std.Concat(output, "static unsigned char ");
        output = std.Concat(output, mir_array_slice_c_array_name(array_index, ctx));
        output = std.Concat(output, "[");
        output = std.Concat(output, std.FormatInt(layout_query.array_layout.total_size));
        output = std.Concat(output, "];\n");
        array_index = array_index + 1;
    }
    output = std.Concat(output, "\nint main(void) {\n");

    array_index = 0;
    while array_index < len(arrays) {
        mut value := arrays[array_index];
        mut layout_query := array_slice.mir_array_slice_array_layout(table, value.array_layout_id, ctx);
        mut element_values: std.Vector[int, ctx] := ctx[value.elements];
        if layout_query.array_layout.nesting_depth == 1 {
            mut element_index := 0;
            while element_index < len(element_values) {
                output = std.Concat(output, "    gust_store(");
                output = std.Concat(output, mir_array_slice_c_array_name(array_index, ctx));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(element_index));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(layout_query.array_layout.element_count));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(layout_query.array_layout.element_stride));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(mir_array_slice_c_width(value.element_type_id)));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(element_values[element_index]));
                output = std.Concat(output, ");\n");
                element_index = element_index + 1;
            }
        }
        array_index = array_index + 1;
    }

    mut slices: std.Vector[array_slice.MirSliceValue[ctx], ctx] := ctx[table.slices];
    mut slice_index := 0;
    while slice_index < len(slices) {
        mut value := slices[slice_index];
        mut source_index := mir_array_slice_c_array_index(table, value.source_array_id, ctx);
        mut source_layout := array_slice.mir_array_slice_array_layout(table, arrays[source_index].array_layout_id, ctx);
        output = std.Concat(output, "    GustSlice ");
        output = std.Concat(output, mir_array_slice_c_slice_name(slice_index, ctx));
        output = std.Concat(output, " = {");
        if value.data_known_null == 1 {
            output = std.Concat(output, "NULL");
        } else {
            output = std.Concat(output, mir_array_slice_c_array_name(source_index, ctx));
            output = std.Concat(output, " + ");
            output = std.Concat(output, std.FormatInt(value.start * source_layout.array_layout.element_stride));
        }
        output = std.Concat(output, ", ");
        output = std.Concat(output, std.FormatInt(value.length));
        output = std.Concat(output, "};\n");
        slice_index = slice_index + 1;
    }

    mut operations: std.Vector[array_slice.MirArraySliceOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        if std.str_eq(operation.kind, "element_address") == 1 ||
           std.str_eq(operation.kind, "element_load") == 1 ||
           std.str_eq(operation.kind, "element_store") == 1
        {
            mut value_index := mir_array_slice_c_array_index(table, operation.array_id, ctx);
            mut value := arrays[value_index];
            mut value_layout := array_slice.mir_array_slice_array_layout(table, value.array_layout_id, ctx);
            if std.str_eq(operation.kind, "element_address") == 1 {
                output = std.Concat(output, "    if ((long long)(");
                output = std.Concat(output, std.FormatInt(operation.index));
                output = std.Concat(output, " * ");
                output = std.Concat(output, std.FormatInt(value_layout.array_layout.element_stride));
                output = std.Concat(output, ") != ");
                output = std.Concat(output, std.FormatInt(operation.expected_address_offset));
                output = std.Concat(output, ") return 82;\n");
            }
            if std.str_eq(operation.kind, "element_load") == 1 {
                output = std.Concat(output, "    if (gust_load(");
                output = std.Concat(output, mir_array_slice_c_array_name(value_index, ctx));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(operation.index));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(value_layout.array_layout.element_count));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(value_layout.array_layout.element_stride));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(mir_array_slice_c_width(value.element_type_id)));
                output = std.Concat(output, ") != "); output = std.Concat(output, std.FormatInt(operation.expected_value));
                output = std.Concat(output, ") return 83;\n");
            }
            if std.str_eq(operation.kind, "element_store") == 1 {
                output = std.Concat(output, "    gust_store(");
                output = std.Concat(output, mir_array_slice_c_array_name(value_index, ctx));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(operation.index));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(value_layout.array_layout.element_count));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(value_layout.array_layout.element_stride));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(mir_array_slice_c_width(value.element_type_id)));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(operation.stored_value));
                output = std.Concat(output, ");\n");
                output = std.Concat(output, "    if (gust_load(");
                output = std.Concat(output, mir_array_slice_c_array_name(value_index, ctx));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(operation.index));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(value_layout.array_layout.element_count));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(value_layout.array_layout.element_stride));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(mir_array_slice_c_width(value.element_type_id)));
                output = std.Concat(output, ") != "); output = std.Concat(output, std.FormatInt(operation.stored_value));
                output = std.Concat(output, ") return 84;\n");
            }
        }
        if std.str_eq(operation.kind, "slice_length") == 1 ||
           std.str_eq(operation.kind, "bounded_index") == 1 ||
           std.str_eq(operation.kind, "subslice") == 1
        {
            mut value_index := mir_array_slice_c_slice_index(table, operation.slice_id, ctx);
            mut value := slices[value_index];
            mut source_index := mir_array_slice_c_array_index(table, value.source_array_id, ctx);
            mut source_layout := array_slice.mir_array_slice_array_layout(table, arrays[source_index].array_layout_id, ctx);
            if std.str_eq(operation.kind, "slice_length") == 1 {
                output = std.Concat(output, "    if (");
                output = std.Concat(output, mir_array_slice_c_slice_name(value_index, ctx));
                output = std.Concat(output, ".length != ");
                output = std.Concat(output, std.FormatInt(operation.expected_value));
                output = std.Concat(output, ") return 85;\n");
            }
            if std.str_eq(operation.kind, "bounded_index") == 1 {
                output = std.Concat(output, "    if (gust_load(");
                output = std.Concat(output, mir_array_slice_c_slice_name(value_index, ctx));
                output = std.Concat(output, ".data, ");
                output = std.Concat(output, std.FormatInt(operation.index));
                output = std.Concat(output, ", "); output = std.Concat(output, mir_array_slice_c_slice_name(value_index, ctx));
                output = std.Concat(output, ".length, "); output = std.Concat(output, std.FormatInt(source_layout.array_layout.element_stride));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(mir_array_slice_c_width(value.element_type_id)));
                output = std.Concat(output, ") != "); output = std.Concat(output, std.FormatInt(operation.expected_value));
                output = std.Concat(output, ") return 86;\n");
            }
            if std.str_eq(operation.kind, "subslice") == 1 {
                output = std.Concat(output, "    if (");
                output = std.Concat(output, std.FormatInt(operation.start + operation.length));
                output = std.Concat(output, " > ");
                output = std.Concat(output, mir_array_slice_c_slice_name(value_index, ctx));
                output = std.Concat(output, ".length) return 87;\n");
            }
        }
        operation_index = operation_index + 1;
    }

    mut witness := array_slice.mir_array_slice_witness(table, layout_table, ctx);
    output = std.Concat(output, "    fputs(\"");
    output = std.Concat(output, mir_array_slice_c_escape(witness, ctx));
    output = std.Concat(output, "\", stdout);\n    return 0;\n}\n");
    return std.Clone(ctx, output);
}
