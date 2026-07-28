// Phase 14.4 MIR-to-C lowering for bounded pointer witnesses.
//
// The compiler-owned pointer table remains semantic authority. This adapter
// emits only address creation, null construction, equality/null tests, checked
// nullability promotion, and aggregate pointer storage. It never dereferences
// or performs pointer arithmetic.

import "mir_layout.gst" as layout;
import "mir_pointer.gst" as pointer;

func mir_pointer_c_escape(value: str, ctx: &Arena) str {
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

func mir_pointer_c_source(table: pointer.MirPointerTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if pointer.mir_pointer_table_is_valid(table, layout_table, ctx) == 0 {
        return "";
    }
    mut witness := pointer.mir_pointer_witness(table, layout_table, ctx);
    mut output := "#include <stddef.h>\n#include <stdio.h>\n\n";
    output = std.Concat(output, "_Static_assert(sizeof(void*) == ");
    output = std.Concat(output, std.FormatInt(layout_table.target.pointer_size));
    output = std.Concat(output, ", \"compiler-selected pointer width mismatch\");\n");
    output = std.Concat(output, "_Static_assert(_Alignof(void*) == ");
    output = std.Concat(output, std.FormatInt(layout_table.target.pointer_alignment));
    output = std.Concat(output, ", \"compiler-selected pointer alignment mismatch\");\n\n");
    output = std.Concat(output, "struct GustPointerHolder { int *field; };\n\n");
    output = std.Concat(output, "int main(void) {\n");
    output = std.Concat(output, "    int local0 = 47;\n");
    output = std.Concat(output, "    int local1 = 48;\n");
    output = std.Concat(output, "    const int *nonnull = &local0;\n");
    output = std.Concat(output, "    const int *nullable = NULL;\n");
    output = std.Concat(output, "    int *mutable_nonnull = &local1;\n");
    output = std.Concat(output, "    struct GustPointerHolder holder = { mutable_nonnull };\n");
    output = std.Concat(output, "    if (nonnull == NULL) return 11;\n");
    output = std.Concat(output, "    if (nullable != NULL) return 12;\n");
    output = std.Concat(output, "    if (!(nullable == NULL)) return 13;\n");
    output = std.Concat(output, "    if (!(nonnull != nullable)) return 14;\n");
    output = std.Concat(output, "    if (holder.field != mutable_nonnull) return 15;\n");
    output = std.Concat(output, "    const int *promoted = nullable;\n");
    output = std.Concat(output, "    if (promoted != NULL) return 16;\n");
    output = std.Concat(output, "    promoted = nonnull;\n");
    output = std.Concat(output, "    if (promoted == NULL) return 17;\n");
    output = std.Concat(output, "    fputs(\"");
    output = std.Concat(output, mir_pointer_c_escape(witness, ctx));
    output = std.Concat(output, "\", stdout);\n");
    output = std.Concat(output, "    return 0;\n}\n");
    return std.Clone(ctx, output);
}