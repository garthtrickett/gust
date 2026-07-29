// Phase 14.6 MIR-to-C typed memory-access lowering.
//
// Widths, alignments, and offsets are emitted only from compiler-owned access
// records. C sizeof is used solely as a verification assertion for the selected
// fixed-width i32 representation, never as the semantic source of truth.

import "mir_layout.gst" as layout;
import "mir_pointer.gst" as pointer;
import "mir_stack_slot.gst" as stack_slot;
import "mir_memory_access.gst" as memory_access;

func mir_memory_access_c_escape(value: str, ctx: &Arena) str {
    mut output := "";
    mut index := 0;
    while index < len(value) {
        mut byte := std.str_byte_at(value, index);
        if byte == 92 {
            output = std.Concat(output, "\\\\");
        } else if byte == 34 {
            output = std.Concat(output, "\\\"");
        } else if byte == 10 {
            output = std.Concat(output, "\\n");
        } else if byte == 13 {
            output = std.Concat(output, "\\r");
        } else {
            output = std.Concat(output, std.str_slice(value, index, index + 1));
        }
        index = index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_memory_access_c_source(table: memory_access.MirMemoryAccessTable[ctx], layout_table: layout.MirLayoutTable[ctx], pointer_table: pointer.MirPointerTable[ctx], stack_slot_table: stack_slot.MirStackSlotTable[ctx], ctx: &Arena) str {
    if memory_access.mir_memory_access_table_is_valid(
        table,
        layout_table,
        pointer_table,
        stack_slot_table,
        ctx
    ) == 0
    {
        return "";
    }
    mut store_stack := memory_access.mir_memory_access_operation(table, "store_stack_i32", ctx);
    mut load_stack := memory_access.mir_memory_access_operation(table, "load_stack_i32", ctx);
    mut store_pointer := memory_access.mir_memory_access_operation(table, "store_pointer_i32", ctx);
    mut load_pointer := memory_access.mir_memory_access_operation(table, "load_pointer_i32", ctx);
    mut offset_second := memory_access.mir_memory_access_operation(table, "offset_aggregate_i32_second", ctx);
    mut copy_element := memory_access.mir_memory_access_operation(table, "copy_aggregate_i32_element", ctx);
    if store_stack.found == 0 || load_stack.found == 0 ||
       store_pointer.found == 0 || load_pointer.found == 0 ||
       offset_second.found == 0 || copy_element.found == 0
    {
        return "";
    }
    mut aggregate_slot := stack_slot.mir_stack_slot(
        stack_slot_table,
        copy_element.operation.origin_slot_id,
        ctx
    );
    if aggregate_slot.found == 0 { return ""; }
    mut witness := memory_access.mir_memory_access_witness(
        table,
        layout_table,
        pointer_table,
        stack_slot_table,
        ctx
    );
    mut output := "#include <stdint.h>\n#include <stdio.h>\n#include <string.h>\n\n";
    output = std.Concat(output, "_Static_assert(sizeof(int32_t) == ");
    output = std.Concat(output, std.FormatInt(store_stack.operation.byte_width));
    output = std.Concat(output, ", \"compiler-selected i32 width mismatch\");\n\n");
    output = std.Concat(output, "int main(void) {\n");
    output = std.Concat(output, "    _Alignas(");
    output = std.Concat(output, std.FormatInt(store_stack.operation.required_alignment));
    output = std.Concat(output, ") int32_t stack_value = 0;\n");
    output = std.Concat(output, "    stack_value = ");
    output = std.Concat(output, std.FormatInt(store_stack.operation.input_value));
    output = std.Concat(output, ";\n");
    output = std.Concat(output, "    int32_t loaded_stack = stack_value;\n");
    output = std.Concat(output, "    _Alignas(");
    output = std.Concat(output, std.FormatInt(store_pointer.operation.required_alignment));
    output = std.Concat(output, ") int32_t pointer_value = 0;\n");
    output = std.Concat(output, "    int32_t *typed_pointer = &pointer_value;\n");
    output = std.Concat(output, "    *typed_pointer = ");
    output = std.Concat(output, std.FormatInt(store_pointer.operation.input_value));
    output = std.Concat(output, ";\n");
    output = std.Concat(output, "    int32_t loaded_pointer = *typed_pointer;\n");
    output = std.Concat(output, "    _Alignas(");
    output = std.Concat(output, std.FormatInt(copy_element.operation.required_alignment));
    output = std.Concat(output, ") unsigned char aggregate[");
    output = std.Concat(output, std.FormatInt(aggregate_slot.slot.size));
    output = std.Concat(output, "] = {0};\n");
    output = std.Concat(output, "    int32_t aggregate_source = ");
    output = std.Concat(output, std.FormatInt(copy_element.operation.input_value));
    output = std.Concat(output, ";\n");
    output = std.Concat(output, "    memcpy(aggregate + ");
    output = std.Concat(output, std.FormatInt(copy_element.operation.source_offset));
    output = std.Concat(output, ", &aggregate_source, ");
    output = std.Concat(output, std.FormatInt(copy_element.operation.byte_width));
    output = std.Concat(output, ");\n");
    output = std.Concat(output, "    memcpy(aggregate + ");
    output = std.Concat(output, std.FormatInt(copy_element.operation.destination_offset));
    output = std.Concat(output, ", aggregate + ");
    output = std.Concat(output, std.FormatInt(copy_element.operation.source_offset));
    output = std.Concat(output, ", ");
    output = std.Concat(output, std.FormatInt(copy_element.operation.byte_width));
    output = std.Concat(output, ");\n");
    output = std.Concat(output, "    int32_t aggregate_loaded = 0;\n");
    output = std.Concat(output, "    memcpy(&aggregate_loaded, aggregate + ");
    output = std.Concat(output, std.FormatInt(offset_second.operation.destination_offset));
    output = std.Concat(output, ", ");
    output = std.Concat(output, std.FormatInt(load_stack.operation.byte_width));
    output = std.Concat(output, ");\n");
    output = std.Concat(output, "    if (loaded_stack != ");
    output = std.Concat(output, std.FormatInt(load_stack.operation.expected_value));
    output = std.Concat(output, ") return 31;\n");
    output = std.Concat(output, "    if (loaded_pointer != ");
    output = std.Concat(output, std.FormatInt(load_pointer.operation.expected_value));
    output = std.Concat(output, ") return 32;\n");
    output = std.Concat(output, "    if (aggregate_loaded != ");
    output = std.Concat(output, std.FormatInt(copy_element.operation.expected_value));
    output = std.Concat(output, ") return 33;\n");
    output = std.Concat(output, "    if (");
    output = std.Concat(output, std.FormatInt(offset_second.operation.destination_offset));
    output = std.Concat(output, " != ");
    output = std.Concat(output, std.FormatInt(offset_second.operation.expected_value));
    output = std.Concat(output, ") return 34;\n");
    output = std.Concat(output, "    fputs(\"");
    output = std.Concat(output, mir_memory_access_c_escape(witness, ctx));
    output = std.Concat(output, "\", stdout);\n");
    output = std.Concat(output, "    return 0;\n}\n");
    return std.Clone(ctx, output);
}