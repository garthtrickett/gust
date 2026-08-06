// Phase 15.7 MIR-to-C evidence for compiler-owned destructor scheduling and
// exactly-once destruction. The generated C replays the compiler-owned state
// machine and fails on any transition violation; it never decides when a
// destructor is needed.

import "mir_layout.gst" as layout;
import "mir_destructor_scheduling.gst" as destructor_scheduling;

func mir_destructor_scheduling_c_escape(value: str, ctx: &Arena) str {
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

func mir_destructor_scheduling_c_state_code(state: str) int {
    if std.str_eq(state, "scheduled") == 1 { return 1; }
    if std.str_eq(state, "cancelled") == 1 { return 2; }
    if std.str_eq(state, "executed") == 1 { return 3; }
    if std.str_eq(state, "destroyed") == 1 { return 4; }
    return 0;
}

func mir_destructor_scheduling_c_source(table: destructor_scheduling.MirDestructorSchedulingTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if destructor_scheduling.mir_destructor_scheduling_table_is_valid(table, layout_table, ctx) == 0 ||
       destructor_scheduling.mir_destructor_scheduling_table_is_legacy_empty(table, ctx) == 1
    {
        return "";
    }

    mut output := "#include <stdio.h>\n#include <string.h>\n#include <stdlib.h>\n\n";
    output = std.Concat(output, "static const int resource_count = 4;\n");
    output = std.Concat(output, "static const int operation_count = 14;\n\n");

    mut resources: std.Vector[destructor_scheduling.MirScheduledResource[ctx], ctx] := ctx[table.resources];
    mut resource_index := 0;
    output = std.Concat(output, "static const char *resource_ids[4] = {");
    resource_index = 0;
    while resource_index < len(resources) {
        if resource_index > 0 { output = std.Concat(output, ", "); }
        output = std.Concat(output, "\"");
        output = std.Concat(output, mir_destructor_scheduling_c_escape(resources[resource_index].resource_id, ctx));
        output = std.Concat(output, "\"");
        resource_index = resource_index + 1;
    }
    output = std.Concat(output, "};\n");

    output = std.Concat(output, "static const char *destructor_ids[4] = {");
    resource_index = 0;
    while resource_index < len(resources) {
        if resource_index > 0 { output = std.Concat(output, ", "); }
        output = std.Concat(output, "\"");
        output = std.Concat(output, mir_destructor_scheduling_c_escape(resources[resource_index].destructor_id, ctx));
        output = std.Concat(output, "\"");
        resource_index = resource_index + 1;
    }
    output = std.Concat(output, "};\n");

    output = std.Concat(output, "static const int declared_orders[4] = {");
    resource_index = 0;
    while resource_index < len(resources) {
        if resource_index > 0 { output = std.Concat(output, ", "); }
        output = std.Concat(output, std.FormatInt(resources[resource_index].destruction_order));
        resource_index = resource_index + 1;
    }
    output = std.Concat(output, "};\n\n");

    output = std.Concat(output, "static int states[4];\n");
    output = std.Concat(output, "static int schedule_counts[4];\n");
    output = std.Concat(output, "static int execution_counts[4];\n");
    output = std.Concat(output, "static int destruction_orders[4];\n\n");

    mut operations: std.Vector[destructor_scheduling.MirDestructorSchedulingOperation[ctx], ctx] := ctx[table.operations];
    output = std.Concat(output, "static const char *operation_kinds[14] = {");
    mut operation_index := 0;
    while operation_index < len(operations) {
        if operation_index > 0 { output = std.Concat(output, ", "); }
        output = std.Concat(output, "\"");
        output = std.Concat(output, mir_destructor_scheduling_c_escape(operations[operation_index].kind, ctx));
        output = std.Concat(output, "\"");
        operation_index = operation_index + 1;
    }
    output = std.Concat(output, "};\n");

    output = std.Concat(output, "static const char *operation_destructors[14] = {");
    operation_index = 0;
    while operation_index < len(operations) {
        if operation_index > 0 { output = std.Concat(output, ", "); }
        output = std.Concat(output, "\"");
        output = std.Concat(output, mir_destructor_scheduling_c_escape(operations[operation_index].destructor_id, ctx));
        output = std.Concat(output, "\"");
        operation_index = operation_index + 1;
    }
    output = std.Concat(output, "};\n");

    output = std.Concat(output, "static const int operation_resources[14] = {");
    operation_index = 0;
    while operation_index < len(operations) {
        mut resource_position := 0;
        mut resource_found := 0;
        mut scan_index := 0;
        while scan_index < len(resources) {
            if std.str_eq(resources[scan_index].resource_id, operations[operation_index].resource_id) == 1 {
                resource_position = scan_index;
                resource_found = 1;
            }
            scan_index = scan_index + 1;
        }
        if resource_found == 0 { return ""; }
        if operation_index > 0 { output = std.Concat(output, ", "); }
        output = std.Concat(output, std.FormatInt(resource_position));
        operation_index = operation_index + 1;
    }
    output = std.Concat(output, "};\n");

    output = std.Concat(output, "static const int operation_expected_orders[14] = {");
    operation_index = 0;
    while operation_index < len(operations) {
        if operation_index > 0 { output = std.Concat(output, ", "); }
        output = std.Concat(output, std.FormatInt(operations[operation_index].expected_order));
        operation_index = operation_index + 1;
    }
    output = std.Concat(output, "};\n\n");

    output = std.Concat(output, "static int operation_failure_reason(int index) {\n");
    output = std.Concat(output, "    int r = operation_resources[index];\n");
    output = std.Concat(output, "    if (strcmp(operation_kinds[index], \"schedule_destructor\") == 0) {\n");
    output = std.Concat(output, "        if (states[r] == 1) return 1;\n");
    output = std.Concat(output, "        if (states[r] != 0 && states[r] != 2) return 2;\n");
    output = std.Concat(output, "        return 0;\n");
    output = std.Concat(output, "    }\n");
    output = std.Concat(output, "    if (strcmp(operation_kinds[index], \"cancel_schedule\") == 0) {\n");
    output = std.Concat(output, "        if (states[r] != 1) return 3;\n");
    output = std.Concat(output, "        return 0;\n");
    output = std.Concat(output, "    }\n");
    output = std.Concat(output, "    if (strcmp(operation_kinds[index], \"execute_destructor\") == 0) {\n");
    output = std.Concat(output, "        if (states[r] == 2) return 4;\n");
    output = std.Concat(output, "        if (states[r] != 1) return 5;\n");
    output = std.Concat(output, "        if (strcmp(operation_destructors[index], destructor_ids[r]) != 0) return 6;\n");
    output = std.Concat(output, "        return 0;\n");
    output = std.Concat(output, "    }\n");
    output = std.Concat(output, "    if (states[r] == 2) return 4;\n");
    output = std.Concat(output, "    if (states[r] == 3) return 0;\n");
    output = std.Concat(output, "    if (states[r] == 4) return 7;\n");
    output = std.Concat(output, "    return 8;\n");
    output = std.Concat(output, "}\n\n");

    output = std.Concat(output, "static void apply_operation(int index) {\n");
    output = std.Concat(output, "    int r = operation_resources[index];\n");
    output = std.Concat(output, "    if (strcmp(operation_kinds[index], \"schedule_destructor\") == 0) {\n");
    output = std.Concat(output, "        states[r] = 1;\n");
    output = std.Concat(output, "        schedule_counts[r] += 1;\n");
    output = std.Concat(output, "    } else if (strcmp(operation_kinds[index], \"cancel_schedule\") == 0) {\n");
    output = std.Concat(output, "        states[r] = 2;\n");
    output = std.Concat(output, "        schedule_counts[r] -= 1;\n");
    output = std.Concat(output, "    } else if (strcmp(operation_kinds[index], \"execute_destructor\") == 0) {\n");
    output = std.Concat(output, "        states[r] = 3;\n");
    output = std.Concat(output, "        execution_counts[r] += 1;\n");
    output = std.Concat(output, "        destruction_orders[r] = operation_expected_orders[index];\n");
    output = std.Concat(output, "    } else {\n");
    output = std.Concat(output, "        states[r] = 4;\n");
    output = std.Concat(output, "    }\n");
    output = std.Concat(output, "}\n\n");

    output = std.Concat(output, "int main(void) {\n");
    output = std.Concat(output, "    for (int i = 0; i < operation_count; i++) {\n");
    output = std.Concat(output, "        int failure = operation_failure_reason(i);\n");
    output = std.Concat(output, "        if (failure != 0) return 90 + failure;\n");
    output = std.Concat(output, "        apply_operation(i);\n");
    output = std.Concat(output, "    }\n");
    output = std.Concat(output, "    for (int r = 0; r < resource_count; r++) {\n");
    output = std.Concat(output, "        if (states[r] != 4 || schedule_counts[r] != 1 ||\n");
    output = std.Concat(output, "            execution_counts[r] != 1 || destruction_orders[r] != declared_orders[r]) {\n");
    output = std.Concat(output, "            return 94;\n");
    output = std.Concat(output, "        }\n");
    output = std.Concat(output, "    }\n");

    mut witness := destructor_scheduling.mir_destructor_scheduling_witness(table, layout_table, ctx);
    output = std.Concat(output, "    fputs(\"");
    output = std.Concat(output, mir_destructor_scheduling_c_escape(witness, ctx));
    output = std.Concat(output, "\", stdout);\n    return 0;\n}\n");
    return std.Clone(ctx, output);
}
