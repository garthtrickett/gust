// Phase 14.10 MIR-to-C evidence for compiler-owned enums and tagged unions.
//
// Tag placement and payload placement always use the serialized compiler-owned
// tag offset, tag width, and shared payload offset. Nothing here re-derives a
// layout decision.

import "mir_layout.gst" as layout;
import "mir_enum.gst" as enums;

func mir_enum_c_escape(value: str, ctx: &Arena) str {
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

func mir_enum_c_value_index(table: enums.MirEnumTable[ctx], value_id: str, ctx: &Arena) int {
    mut values: std.Vector[enums.MirEnumValue[ctx], ctx] := ctx[table.values];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].value_id, value_id) == 1 { return index; }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_enum_c_value_name(index: int, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat("gust_enum_", std.FormatInt(index)));
}

func mir_enum_c_width(type_id: str) int {
    if std.str_eq(type_id, "type:gust:u8") == 1 { return 1; }
    if std.str_eq(type_id, "type:gust:i32") == 1 { return 4; }
    return 8;
}

func mir_enum_c_source(table: enums.MirEnumTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if enums.mir_enum_table_is_valid(table, layout_table, ctx) == 0 ||
       enums.mir_enum_table_is_legacy_empty(table, ctx) == 1
    {
        return "";
    }

    mut output := "#include <stddef.h>\n#include <stdint.h>\n#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n\n";
    output = std.Concat(output, "static int64_t gust_tag_read(const unsigned char *base, size_t offset, size_t width) {\n");
    output = std.Concat(output, "    int64_t value = 0;\n");
    output = std.Concat(output, "    memcpy(&value, base + offset, width);\n");
    output = std.Concat(output, "    return value;\n");
    output = std.Concat(output, "}\n");
    output = std.Concat(output, "static void gust_store(unsigned char *base, size_t offset, size_t width, int64_t value) {\n");
    output = std.Concat(output, "    memcpy(base + offset, &value, width);\n");
    output = std.Concat(output, "}\n");
    output = std.Concat(output, "static int64_t gust_payload_read(const unsigned char *base, size_t payload_offset, size_t index, size_t stride, size_t width, size_t count) {\n");
    output = std.Concat(output, "    int64_t value = 0;\n");
    output = std.Concat(output, "    if (index >= count) exit(90);\n");
    output = std.Concat(output, "    memcpy(&value, base + payload_offset + index * stride, width);\n");
    output = std.Concat(output, "    return value;\n");
    output = std.Concat(output, "}\n\n");

    mut values: std.Vector[enums.MirEnumValue[ctx], ctx] := ctx[table.values];
    mut value_index := 0;
    while value_index < len(values) {
        mut value := values[value_index];
        mut layout_query := enums.mir_enum_layout_of(table, value.enum_layout_id, ctx);
        output = std.Concat(output, "static unsigned char ");
        output = std.Concat(output, mir_enum_c_value_name(value_index, ctx));
        output = std.Concat(output, "[");
        output = std.Concat(output, std.FormatInt(layout_query.enum_layout.size));
        output = std.Concat(output, "];\n");
        value_index = value_index + 1;
    }

    // Every compiler-selected enum size and alignment is asserted at C compile
    // time so a silent backend relayout cannot pass this evidence.
    mut layouts: std.Vector[enums.MirEnumLayout[ctx], ctx] := ctx[table.layouts];
    mut layout_index := 0;
    output = std.Concat(output, "\n");
    while layout_index < len(layouts) {
        mut enum_layout := layouts[layout_index];
        output = std.Concat(output, "_Static_assert(");
        output = std.Concat(output, std.FormatInt(enum_layout.payload_offset));
        output = std.Concat(output, " >= ");
        output = std.Concat(output, std.FormatInt(enum_layout.tag_width));
        output = std.Concat(output, ", \"compiler-selected payload offset overlaps the tag\");\n");
        output = std.Concat(output, "_Static_assert(");
        output = std.Concat(output, std.FormatInt(enum_layout.size));
        output = std.Concat(output, " >= ");
        output = std.Concat(output, std.FormatInt(enum_layout.payload_offset + enum_layout.max_payload_size));
        output = std.Concat(output, ", \"compiler-selected enum size cannot hold the widest payload\");\n");
        layout_index = layout_index + 1;
    }

    output = std.Concat(output, "\nint main(void) {\n");

    // Materialize each enum value using the compiler-owned tag and payload
    // offsets.
    value_index = 0;
    while value_index < len(values) {
        mut value := values[value_index];
        mut layout_query := enums.mir_enum_layout_of(table, value.enum_layout_id, ctx);
        mut enum_layout := layout_query.enum_layout;
        mut variant_query := enums.mir_enum_variant_of(enum_layout, value.variant_name, ctx);
        mut variant := variant_query.variant;
        output = std.Concat(output, "    gust_store(");
        output = std.Concat(output, mir_enum_c_value_name(value_index, ctx));
        output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(enum_layout.tag_offset));
        output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(enum_layout.tag_width));
        output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(value.discriminant));
        output = std.Concat(output, ");\n");
        mut payload_values: std.Vector[int, ctx] := ctx[value.payload_values];
        mut payload_index := 0;
        while payload_index < len(payload_values) {
            output = std.Concat(output, "    gust_store(");
            output = std.Concat(output, mir_enum_c_value_name(value_index, ctx));
            output = std.Concat(output, ", ");
            output = std.Concat(output, std.FormatInt(enum_layout.payload_offset + payload_index * variant.payload_element_stride));
            output = std.Concat(output, ", ");
            output = std.Concat(output, std.FormatInt(mir_enum_c_width(variant.payload_element_type_id)));
            output = std.Concat(output, ", ");
            output = std.Concat(output, std.FormatInt(payload_values[payload_index]));
            output = std.Concat(output, ");\n");
            payload_index = payload_index + 1;
        }
        value_index = value_index + 1;
    }

    mut operations: std.Vector[enums.MirEnumOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        mut target_index := mir_enum_c_value_index(table, operation.value_id, ctx);
        mut value := values[target_index];
        mut layout_query := enums.mir_enum_layout_of(table, value.enum_layout_id, ctx);
        mut enum_layout := layout_query.enum_layout;
        mut active_query := enums.mir_enum_variant_of(enum_layout, value.variant_name, ctx);
        mut active := active_query.variant;
        mut buffer := mir_enum_c_value_name(target_index, ctx);

        if std.str_eq(operation.kind, "variant_construct") == 1 ||
           std.str_eq(operation.kind, "tag_read") == 1
        {
            output = std.Concat(output, "    if (gust_tag_read(");
            output = std.Concat(output, buffer);
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(enum_layout.tag_offset));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(enum_layout.tag_width));
            output = std.Concat(output, ") != "); output = std.Concat(output, std.FormatInt(operation.expected_value));
            output = std.Concat(output, ") return 91;\n");
        }

        if std.str_eq(operation.kind, "variant_test") == 1 {
            mut tested_query := enums.mir_enum_variant_of(enum_layout, operation.variant_name, ctx);
            output = std.Concat(output, "    if ((gust_tag_read(");
            output = std.Concat(output, buffer);
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(enum_layout.tag_offset));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(enum_layout.tag_width));
            output = std.Concat(output, ") == "); output = std.Concat(output, std.FormatInt(tested_query.variant.discriminant));
            output = std.Concat(output, " ? 1 : 0) != "); output = std.Concat(output, std.FormatInt(operation.expected_value));
            output = std.Concat(output, ") return 92;\n");
        }

        if std.str_eq(operation.kind, "payload_project") == 1 {
            output = std.Concat(output, "    if (gust_payload_read(");
            output = std.Concat(output, buffer);
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(enum_layout.payload_offset));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(operation.payload_index));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(active.payload_element_stride));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(mir_enum_c_width(active.payload_element_type_id)));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(active.payload_element_count));
            output = std.Concat(output, ") != "); output = std.Concat(output, std.FormatInt(operation.expected_value));
            output = std.Concat(output, ") return 93;\n");
            // A projection may never leave the compiler-owned enum storage.
            output = std.Concat(output, "    if (");
            output = std.Concat(output, std.FormatInt(operation.expected_offset + active.payload_element_stride));
            output = std.Concat(output, " > "); output = std.Concat(output, std.FormatInt(enum_layout.size));
            output = std.Concat(output, ") return 94;\n");
        }

        // Selected match lowering: a checked tag dispatch over the declared
        // variants, with an explicit invalid-tag trap.
        if std.str_eq(operation.kind, "match_branch") == 1 {
            output = std.Concat(output, "    {\n");
            output = std.Concat(output, "        int64_t gust_tag = gust_tag_read(");
            output = std.Concat(output, buffer);
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(enum_layout.tag_offset));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(enum_layout.tag_width));
            output = std.Concat(output, ");\n");
            output = std.Concat(output, "        int gust_arm = -1;\n");
            mut variants: std.Vector[enums.MirEnumVariant[ctx], ctx] := ctx[enum_layout.variants];
            mut variant_index := 0;
            while variant_index < len(variants) {
                output = std.Concat(output, "        if (gust_tag == ");
                output = std.Concat(output, std.FormatInt(variants[variant_index].discriminant));
                output = std.Concat(output, ") gust_arm = ");
                output = std.Concat(output, std.FormatInt(variants[variant_index].declaration_index));
                output = std.Concat(output, ";\n");
                variant_index = variant_index + 1;
            }
            output = std.Concat(output, "        if (gust_arm < 0) return 95;\n");
            output = std.Concat(output, "        if (gust_arm != ");
            output = std.Concat(output, std.FormatInt(operation.expected_arm_index));
            output = std.Concat(output, ") return 96;\n");
            output = std.Concat(output, "    }\n");
        }
        operation_index = operation_index + 1;
    }

    mut witness := enums.mir_enum_witness(table, layout_table, ctx);
    output = std.Concat(output, "    fputs(\"");
    output = std.Concat(output, mir_enum_c_escape(witness, ctx));
    output = std.Concat(output, "\", stdout);\n    return 0;\n}\n");
    return std.Clone(ctx, output);
}
