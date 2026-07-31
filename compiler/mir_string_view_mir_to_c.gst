// Phase 14.7 MIR-to-C consumer for compiler-owned string literals and views.
// It consumes the same serialized semantic records as the Cranelift worker.
// The generated C uses explicit lengths and byte arrays; NUL termination is
// never consulted for string length, slicing, indexing, or comparison.

import "mir_layout.gst" as layout;
import "mir_string_view.gst" as string_view;

func mir_string_view_c_hex_byte(bytes_hex: str, byte_index: int, ctx: &Arena) str {
    mut start := byte_index * 2;
    mut pair := std.str_slice(bytes_hex, start, start + 2);
    return std.Clone(ctx, std.Concat("0x", pair));
}

func mir_string_view_c_literal_declaration(literal: string_view.MirStringLiteralStorage[ctx], ctx: &Arena) str {
    mut output := "static const unsigned char ";
    output = std.Concat(output, literal.symbol_name);
    output = std.Concat(output, "[] = {");
    if literal.byte_length == 0 {
        output = std.Concat(output, "0x00");
    } else {
        mut index := 0;
        while index < literal.byte_length {
            if index > 0 { output = std.Concat(output, ", "); }
            output = std.Concat(output, mir_string_view_c_hex_byte(literal.bytes_hex, index, ctx));
            index = index + 1;
        }
    }
    output = std.Concat(output, "};\n");
    output = std.Concat(output, "static const size_t ");
    output = std.Concat(output, literal.symbol_name);
    output = std.Concat(output, "_len = ");
    output = std.Concat(output, std.FormatInt(literal.byte_length));
    output = std.Concat(output, ";\n");
    return std.Clone(ctx, output);
}

func mir_string_view_c_view_name(index: int, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat("gust_view_", std.FormatInt(index)));
}

func mir_string_view_c_view_index(table: string_view.MirStringViewTable[ctx], view_id: str, ctx: &Arena) int {
    mut views: std.Vector[string_view.MirStringView[ctx], ctx] := ctx[table.views];
    mut index := 0;
    while index < len(views) {
        if std.str_eq(views[index].view_id, view_id) == 1 { return index; }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_string_view_c_view_declaration(table: string_view.MirStringViewTable[ctx], view: string_view.MirStringView[ctx], view_index: int, ctx: &Arena) str {
    mut literal_query := string_view.mir_string_view_literal(table, view.source_literal_id, ctx);
    if literal_query.found == 0 { return ""; }
    mut output := "static const GustStringView ";
    output = std.Concat(output, mir_string_view_c_view_name(view_index, ctx));
    output = std.Concat(output, " = {");
    output = std.Concat(output, literal_query.literal.symbol_name);
    output = std.Concat(output, " + ");
    output = std.Concat(output, std.FormatInt(view.start));
    output = std.Concat(output, ", ");
    output = std.Concat(output, std.FormatInt(view.length));
    output = std.Concat(output, "};\n");
    return std.Clone(ctx, output);
}

func mir_string_view_c_puts_line(line: str, ctx: &Arena) str {
    mut output := "    puts(\"";
    output = std.Concat(output, line);
    output = std.Concat(output, "\");\n");
    return std.Clone(ctx, output);
}

func mir_string_view_c_operation(table: string_view.MirStringViewTable[ctx], operation: string_view.MirStringViewOperation[ctx], operation_index: int, ctx: &Arena) str {
    mut value_expression := "0";
    mut result_start_expression := std.FormatInt(operation.expected_result_start);
    mut result_length_expression := std.FormatInt(operation.expected_result_length);
    mut prelude := "";

    if std.str_eq(operation.kind, "literal_create") == 1 {
        mut literal := string_view.mir_string_view_literal(table, operation.literal_id, ctx);
        if literal.found == 0 { return ""; }
        value_expression = std.Concat(literal.literal.symbol_name, "_len");
    }
    if std.str_eq(operation.kind, "view_create") == 1 {
        mut literal := string_view.mir_string_view_literal(table, operation.literal_id, ctx);
        if literal.found == 0 { return ""; }
        mut result_name := std.Concat("gust_operation_view_", std.FormatInt(operation_index));
        prelude = std.Concat("    GustStringView ", result_name);
        prelude = std.Concat(prelude, " = {");
        prelude = std.Concat(prelude, literal.literal.symbol_name);
        prelude = std.Concat(prelude, " + ");
        prelude = std.Concat(prelude, std.FormatInt(operation.start));
        prelude = std.Concat(prelude, ", ");
        prelude = std.Concat(prelude, std.FormatInt(operation.length));
        prelude = std.Concat(prelude, "};\n");
        value_expression = std.Concat(result_name, ".length");
        result_start_expression = std.FormatInt(operation.start);
        result_length_expression = std.Concat(result_name, ".length");
    }
    if std.str_eq(operation.kind, "length") == 1 {
        mut index := mir_string_view_c_view_index(table, operation.view_id, ctx);
        if index < 0 { return ""; }
        value_expression = std.Concat(mir_string_view_c_view_name(index, ctx), ".length");
        result_length_expression = value_expression;
    }
    if std.str_eq(operation.kind, "is_empty") == 1 {
        mut index := mir_string_view_c_view_index(table, operation.view_id, ctx);
        if index < 0 { return ""; }
        value_expression = std.Concat("(", mir_string_view_c_view_name(index, ctx));
        value_expression = std.Concat(value_expression, ".length == 0 ? 1 : 0)");
    }
    if std.str_eq(operation.kind, "byte_at") == 1 {
        mut index := mir_string_view_c_view_index(table, operation.view_id, ctx);
        if index < 0 { return ""; }
        value_expression = std.Concat(mir_string_view_c_view_name(index, ctx), ".data[");
        value_expression = std.Concat(value_expression, std.FormatInt(operation.index));
        value_expression = std.Concat(value_expression, "]");
    }
    if std.str_eq(operation.kind, "slice") == 1 {
        mut index := mir_string_view_c_view_index(table, operation.view_id, ctx);
        if index < 0 { return ""; }
        mut source_name := mir_string_view_c_view_name(index, ctx);
        mut result_name := std.Concat("gust_operation_view_", std.FormatInt(operation_index));
        prelude = std.Concat("    GustStringView ", result_name);
        prelude = std.Concat(prelude, " = {");
        prelude = std.Concat(prelude, source_name);
        prelude = std.Concat(prelude, ".data + ");
        prelude = std.Concat(prelude, std.FormatInt(operation.start));
        prelude = std.Concat(prelude, ", ");
        prelude = std.Concat(prelude, std.FormatInt(operation.length));
        prelude = std.Concat(prelude, "};\n");
        value_expression = std.Concat(result_name, ".length");
        result_start_expression = std.FormatInt(operation.expected_result_start);
        result_length_expression = std.Concat(result_name, ".length");
    }
    if std.str_eq(operation.kind, "byte_equal") == 1 {
        mut lhs_index := mir_string_view_c_view_index(table, operation.view_id, ctx);
        mut rhs_index := mir_string_view_c_view_index(table, operation.rhs_view_id, ctx);
        if lhs_index < 0 || rhs_index < 0 { return ""; }
        value_expression = "gust_string_view_equal(";
        value_expression = std.Concat(value_expression, mir_string_view_c_view_name(lhs_index, ctx));
        value_expression = std.Concat(value_expression, ", ");
        value_expression = std.Concat(value_expression, mir_string_view_c_view_name(rhs_index, ctx));
        value_expression = std.Concat(value_expression, ")");
    }

    mut output := prelude;
    output = std.Concat(output, "    printf(\"string_operation: ");
    output = std.Concat(output, operation.operation_name);
    output = std.Concat(output, " kind=");
    output = std.Concat(output, operation.kind);
    output = std.Concat(output, " status=success value=%lld result_start=%lld result_length=%lld reason=string_view_valid\\n\", (long long)(");
    output = std.Concat(output, value_expression);
    output = std.Concat(output, "), (long long)(");
    output = std.Concat(output, result_start_expression);
    output = std.Concat(output, "), (long long)(");
    output = std.Concat(output, result_length_expression);
    output = std.Concat(output, "));\n");
    return std.Clone(ctx, output);
}

func mir_string_view_c_source(table: string_view.MirStringViewTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if string_view.mir_string_view_table_is_valid(table, layout_table, ctx) == 0 ||
       string_view.mir_string_view_table_is_legacy_empty(table, ctx) == 1
    {
        return "";
    }

    mut output := "#include <stddef.h>\n#include <stdint.h>\n#include <stdio.h>\n#include <string.h>\n\n";
    output = std.Concat(output, "typedef struct { const unsigned char *data; size_t length; } GustStringView;\n");
    output = std.Concat(output, "_Static_assert(sizeof(GustStringView) == ");
    output = std.Concat(output, std.FormatInt(table.view_layout.size));
    output = std.Concat(output, ", \"compiler-selected string-view size mismatch\");\n");
    output = std.Concat(output, "_Static_assert(_Alignof(GustStringView) == ");
    output = std.Concat(output, std.FormatInt(table.view_layout.alignment));
    output = std.Concat(output, ", \"compiler-selected string-view alignment mismatch\");\n\n");

    mut literals: std.Vector[string_view.MirStringLiteralStorage[ctx], ctx] := ctx[table.literals];
    mut literal_index := 0;
    while literal_index < len(literals) {
        output = std.Concat(output, mir_string_view_c_literal_declaration(literals[literal_index], ctx));
        literal_index = literal_index + 1;
    }
    output = std.Concat(output, "\n");

    mut views: std.Vector[string_view.MirStringView[ctx], ctx] := ctx[table.views];
    mut view_index := 0;
    while view_index < len(views) {
        output = std.Concat(output, mir_string_view_c_view_declaration(table, views[view_index], view_index, ctx));
        view_index = view_index + 1;
    }
    output = std.Concat(output, "\nstatic int gust_string_view_equal(GustStringView lhs, GustStringView rhs) {\n");
    output = std.Concat(output, "    return lhs.length == rhs.length && (lhs.length == 0 || memcmp(lhs.data, rhs.data, lhs.length) == 0);\n}\n\n");
    output = std.Concat(output, "int main(void) {\n");
    output = std.Concat(output, mir_string_view_c_puts_line("string_view_status: valid", ctx));
    output = std.Concat(output, mir_string_view_c_puts_line(std.Concat("string_view_target: ", table.target_triple), ctx));
    output = std.Concat(output, mir_string_view_c_puts_line(std.Concat("string_view_target_id: ", table.target_id), ctx));
    output = std.Concat(output, mir_string_view_c_puts_line(std.Concat("string_view_source_encoding: ", table.source_encoding), ctx));
    output = std.Concat(output, mir_string_view_c_puts_line(std.Concat("string_view_literal_encoding: ", table.literal_encoding), ctx));
    output = std.Concat(output, mir_string_view_c_puts_line(std.Concat("string_view_embedded_nul_policy: ", table.embedded_nul_policy), ctx));
    output = std.Concat(output, mir_string_view_c_puts_line(std.Concat("string_view_empty_string_policy: ", table.empty_string_policy), ctx));
    output = std.Concat(output, mir_string_view_c_puts_line(std.Concat("string_view_semantic_length_authority: ", table.semantic_length_authority), ctx));
    output = std.Concat(output, mir_string_view_c_puts_line(std.Concat("string_view_owning_string_policy: ", table.owning_string_policy), ctx));
    output = std.Concat(output, mir_string_view_c_puts_line(std.Concat("string_view_mutation_policy: ", table.mutation_policy), ctx));
    output = std.Concat(output, mir_string_view_c_puts_line(std.Concat("string_view_concatenation_policy: ", table.concatenation_policy), ctx));
    output = std.Concat(output, mir_string_view_c_puts_line(std.Concat("string_view_allocation_policy: ", table.allocation_policy), ctx));

    mut layout_line := "string_view_layout: ";
    layout_line = std.Concat(layout_line, table.view_layout.layout_id);
    layout_line = std.Concat(layout_line, " type=");
    layout_line = std.Concat(layout_line, table.view_layout.view_type_id);
    layout_line = std.Concat(layout_line, " size=");
    layout_line = std.Concat(layout_line, std.FormatInt(table.view_layout.size));
    layout_line = std.Concat(layout_line, " alignment=");
    layout_line = std.Concat(layout_line, std.FormatInt(table.view_layout.alignment));
    layout_line = std.Concat(layout_line, " data_offset=");
    layout_line = std.Concat(layout_line, std.FormatInt(table.view_layout.data_pointer_offset));
    layout_line = std.Concat(layout_line, " length_offset=");
    layout_line = std.Concat(layout_line, std.FormatInt(table.view_layout.length_offset));
    layout_line = std.Concat(layout_line, " pointer_size=");
    layout_line = std.Concat(layout_line, std.FormatInt(table.view_layout.pointer_size));
    output = std.Concat(output, mir_string_view_c_puts_line(layout_line, ctx));

    literal_index = 0;
    while literal_index < len(literals) {
        mut literal := literals[literal_index];
        mut line := "string_literal: ";
        line = std.Concat(line, literal.literal_id);
        line = std.Concat(line, " symbol=");
        line = std.Concat(line, literal.symbol_name);
        line = std.Concat(line, " encoding=");
        line = std.Concat(line, literal.encoding);
        line = std.Concat(line, " length=");
        line = std.Concat(line, std.FormatInt(literal.byte_length));
        line = std.Concat(line, " bytes=");
        line = std.Concat(line, literal.bytes_hex);
        line = std.Concat(line, " storage=");
        line = std.Concat(line, literal.storage_kind);
        line = std.Concat(line, " lifetime=");
        line = std.Concat(line, literal.lifetime_region);
        output = std.Concat(output, mir_string_view_c_puts_line(line, ctx));
        literal_index = literal_index + 1;
    }

    view_index = 0;
    while view_index < len(views) {
        mut view := views[view_index];
        mut line := "string_view: ";
        line = std.Concat(line, view.view_id);
        line = std.Concat(line, " source=");
        line = std.Concat(line, view.source_literal_id);
        line = std.Concat(line, " start=");
        line = std.Concat(line, std.FormatInt(view.start));
        line = std.Concat(line, " length=");
        line = std.Concat(line, std.FormatInt(view.length));
        line = std.Concat(line, " known_null=");
        line = std.Concat(line, std.FormatInt(view.data_known_null));
        line = std.Concat(line, " lifetime=");
        line = std.Concat(line, view.lifetime_region);
        output = std.Concat(output, mir_string_view_c_puts_line(line, ctx));
        view_index = view_index + 1;
    }

    mut operations: std.Vector[string_view.MirStringViewOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        output = std.Concat(output, mir_string_view_c_operation(table, operations[operation_index], operation_index, ctx));
        operation_index = operation_index + 1;
    }
    output = std.Concat(output, "    return 0;\n}\n");
    return std.Clone(ctx, output);
}