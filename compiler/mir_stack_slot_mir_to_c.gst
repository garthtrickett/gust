// Phase 14.5 MIR-to-C stack-slot witness lowering.
//
// This adapter materializes fixed-size addressable scalar locals, one
// compiler temporary, and one bounded two-i32 aggregate. It does not emit
// dynamic allocation, escaping addresses, resource-bearing storage, or
// unbounded aliasing.

import "mir_layout.gst" as layout;
import "mir_stack_slot.gst" as stack_slot;

func mir_stack_slot_c_escape(value: str, ctx: &Arena) str {
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

func mir_stack_slot_c_source(table: stack_slot.MirStackSlotTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if stack_slot.mir_stack_slot_table_is_valid(table, layout_table, ctx) == 0 { return ""; }
    mut witness := stack_slot.mir_stack_slot_witness(table, layout_table, ctx);
    mut output := "#include <stddef.h>\n#include <stdio.h>\n\n";
    output = std.Concat(output, "struct GustPairI32 { int first; int second; };\n\n");
    output = std.Concat(output, "int main(void) {\n");
    output = std.Concat(output, "    int addressable = 51;\n");
    output = std.Concat(output, "    int *address = &addressable;\n");
    output = std.Concat(output, "    *address = 52;\n");
    output = std.Concat(output, "    int branch_local = 52;\n");
    output = std.Concat(output, "    if (branch_local == 52) branch_local = 53;\n");
    output = std.Concat(output, "    int temporary = 0;\n");
    output = std.Concat(output, "    for (int i = 0; i < 5; ++i) temporary += 11;\n");
    output = std.Concat(output, "    struct GustPairI32 aggregate = { 50, 51 };\n");
    output = std.Concat(output, "    struct GustPairI32 aggregate_copy = aggregate;\n");
    output = std.Concat(output, "    if (addressable != 52) return 21;\n");
    output = std.Concat(output, "    if (branch_local != 53) return 22;\n");
    output = std.Concat(output, "    if (temporary != 55) return 23;\n");
    output = std.Concat(output, "    if (aggregate_copy.first + aggregate_copy.second != 101) return 24;\n");
    output = std.Concat(output, "    fputs(\"");
    output = std.Concat(output, mir_stack_slot_c_escape(witness, ctx));
    output = std.Concat(output, "\", stdout);\n");
    output = std.Concat(output, "    return 0;\n}\n");
    return std.Clone(ctx, output);
}