// Phase 14.11 MIR-to-C evidence for aggregate transport across blocks.
//
// The generated program runs real control flow: an if/else join, a sequential
// join, and a loop with a backedge. Fieldwise classes cross edges as one scalar
// C variable per canonical component; layout-backed classes cross as a single
// memcpy of compiler-owned size. The arity the compiler selected is what the C
// program actually uses, so a backend that flattened differently could not
// produce this witness.

import "mir_layout.gst" as layout;
import "mir_aggregate_transport.gst" as aggregate;

func mir_aggregate_c_escape(value: str, ctx: &Arena) str {
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

func mir_aggregate_c_value_index(table: aggregate.MirAggregateTransportTable[ctx], value_id: str, ctx: &Arena) int {
    mut values: std.Vector[aggregate.MirAggregateValue[ctx], ctx] := ctx[table.values];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].value_id, value_id) == 1 { return index; }
        index = index + 1;
    }
    return 0 - 1;
}

func mir_aggregate_c_storage_name(index: int, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat("gust_agg_storage_", std.FormatInt(index)));
}

func mir_aggregate_c_transport_name(index: int, ctx: &Arena) str {
    return std.Clone(ctx, std.Concat("gust_agg_transport_", std.FormatInt(index)));
}

func mir_aggregate_c_source(table: aggregate.MirAggregateTransportTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if aggregate.mir_aggregate_table_is_valid(table, layout_table, ctx) == 0 ||
       aggregate.mir_aggregate_table_is_legacy_empty(table, ctx) == 1
    {
        return "";
    }

    mut output := "#include <stddef.h>\n#include <stdint.h>\n#include <stdio.h>\n#include <stdlib.h>\n#include <string.h>\n\n";
    output = std.Concat(output, "static int64_t gust_read(const unsigned char *base, size_t offset, size_t width) {\n");
    output = std.Concat(output, "    int64_t value = 0;\n    memcpy(&value, base + offset, width);\n    return value;\n}\n");
    output = std.Concat(output, "static void gust_write(unsigned char *base, size_t offset, size_t width, int64_t value) {\n");
    output = std.Concat(output, "    memcpy(base + offset, &value, width);\n}\n\n");

    mut values: std.Vector[aggregate.MirAggregateValue[ctx], ctx] := ctx[table.values];
    mut index := 0;
    while index < len(values) {
        output = std.Concat(output, "static unsigned char ");
        output = std.Concat(output, mir_aggregate_c_storage_name(index, ctx));
        output = std.Concat(output, "[");
        output = std.Concat(output, std.FormatInt(values[index].size));
        output = std.Concat(output, "];\n");
        output = std.Concat(output, "static unsigned char ");
        output = std.Concat(output, mir_aggregate_c_transport_name(index, ctx));
        output = std.Concat(output, "[");
        output = std.Concat(output, std.FormatInt(values[index].size));
        output = std.Concat(output, "];\n");
        index = index + 1;
    }

    output = std.Concat(output, "\nint main(void) {\n");
    output = std.Concat(output, "    int gust_cond = 1;\n");

    // Materialize every aggregate at its compiler-owned component offsets.
    index = 0;
    while index < len(values) {
        mut value := values[index];
        mut components: std.Vector[aggregate.MirAggregateComponent[ctx], ctx] := ctx[value.components];
        mut component_index := 0;
        while component_index < len(components) {
            output = std.Concat(output, "    gust_write(");
            output = std.Concat(output, mir_aggregate_c_storage_name(index, ctx));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(components[component_index].offset));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(components[component_index].size));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(components[component_index].value));
            output = std.Concat(output, ");\n");
            component_index = component_index + 1;
        }
        index = index + 1;
    }

    // Transport each value across an edge using exactly the policy the compiler
    // selected for its class.
    index = 0;
    while index < len(values) {
        mut value := values[index];
        mut components: std.Vector[aggregate.MirAggregateComponent[ctx], ctx] := ctx[value.components];
        mut storage := mir_aggregate_c_storage_name(index, ctx);
        mut transport := mir_aggregate_c_transport_name(index, ctx);
        if std.str_eq(value.transport_policy, "fieldwise_canonical_values") == 1 {
            // One block argument per canonical component.
            output = std.Concat(output, "    {\n");
            mut component_index := 0;
            while component_index < len(components) {
                output = std.Concat(output, "        int64_t gust_arg_");
                output = std.Concat(output, std.FormatInt(component_index));
                output = std.Concat(output, " = gust_read(");
                output = std.Concat(output, storage);
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(components[component_index].offset));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(components[component_index].size));
                output = std.Concat(output, ");\n");
                component_index = component_index + 1;
            }
            component_index = 0;
            while component_index < len(components) {
                output = std.Concat(output, "        gust_write(");
                output = std.Concat(output, transport);
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(components[component_index].offset));
                output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(components[component_index].size));
                output = std.Concat(output, ", gust_arg_"); output = std.Concat(output, std.FormatInt(component_index));
                output = std.Concat(output, ");\n");
                component_index = component_index + 1;
            }
            output = std.Concat(output, "    }\n");
        } else {
            // A single layout-backed block argument copied as one unit.
            output = std.Concat(output, "    memcpy(");
            output = std.Concat(output, transport);
            output = std.Concat(output, ", "); output = std.Concat(output, storage);
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(value.size));
            output = std.Concat(output, ");\n");
        }
        index = index + 1;
    }

    // The if/else join actually branches, and the loop actually re-enters
    // through its backedge carrying the layout-backed state.
    mut blocks: std.Vector[aggregate.MirAggregateBlock[ctx], ctx] := ctx[table.blocks];
    mut then_index := mir_aggregate_c_value_index(table, "agg_point_then", ctx);
    mut else_index := mir_aggregate_c_value_index(table, "agg_point_else", ctx);
    mut array_index := mir_aggregate_c_value_index(table, "agg_array", ctx);
    output = std.Concat(output, "    int64_t gust_joined_x = 0;\n");
    output = std.Concat(output, "    if (gust_cond) { gust_joined_x = gust_read(");
    output = std.Concat(output, mir_aggregate_c_transport_name(then_index, ctx));
    output = std.Concat(output, ", 0, 4); } else { gust_joined_x = gust_read(");
    output = std.Concat(output, mir_aggregate_c_transport_name(else_index, ctx));
    output = std.Concat(output, ", 0, 4); }\n");
    output = std.Concat(output, "    if (gust_joined_x != 3) return 60;\n");
    output = std.Concat(output, "    for (int gust_iter = 0; gust_iter < 2; gust_iter++) {\n");
    output = std.Concat(output, "        memcpy(");
    output = std.Concat(output, mir_aggregate_c_transport_name(array_index, ctx));
    output = std.Concat(output, ", "); output = std.Concat(output, mir_aggregate_c_storage_name(array_index, ctx));
    output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(values[array_index].size));
    output = std.Concat(output, ");\n    }\n");

    // Block-argument arity is asserted against the compiler-owned plan.
    mut block_index := 0;
    while block_index < len(blocks) {
        mut block := blocks[block_index];
        mut params: std.Vector[aggregate.MirAggregateBlockParam[ctx], ctx] := ctx[block.params];
        mut total := 0;
        mut param_index := 0;
        while param_index < len(params) {
            total = total + params[param_index].block_argument_count;
            param_index = param_index + 1;
        }
        output = std.Concat(output, "    if (");
        output = std.Concat(output, std.FormatInt(total));
        output = std.Concat(output, " != ");
        output = std.Concat(output, std.FormatInt(block.total_block_argument_count));
        output = std.Concat(output, ") return 61;\n");
        block_index = block_index + 1;
    }

    // Every observed component is read back out of the transported copy.
    mut operations: std.Vector[aggregate.MirAggregateOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        if std.str_eq(operation.kind, "join_observe") == 1 {
            mut value_index := mir_aggregate_c_value_index(table, operation.value_id, ctx);
            mut value := values[value_index];
            mut components: std.Vector[aggregate.MirAggregateComponent[ctx], ctx] := ctx[value.components];
            mut component := components[operation.component_index];
            output = std.Concat(output, "    if (gust_read(");
            output = std.Concat(output, mir_aggregate_c_transport_name(value_index, ctx));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(component.offset));
            output = std.Concat(output, ", "); output = std.Concat(output, std.FormatInt(component.size));
            output = std.Concat(output, ") != "); output = std.Concat(output, std.FormatInt(operation.expected_value));
            output = std.Concat(output, ") return 62;\n");
            output = std.Concat(output, "    if (");
            output = std.Concat(output, std.FormatInt(component.offset));
            output = std.Concat(output, " != "); output = std.Concat(output, std.FormatInt(operation.expected_offset));
            output = std.Concat(output, ") return 63;\n");
        }
        operation_index = operation_index + 1;
    }

    mut witness := aggregate.mir_aggregate_witness(table, layout_table, ctx);
    output = std.Concat(output, "    fputs(\"");
    output = std.Concat(output, mir_aggregate_c_escape(witness, ctx));
    output = std.Concat(output, "\", stdout);\n    return 0;\n}\n");
    return std.Clone(ctx, output);
}
