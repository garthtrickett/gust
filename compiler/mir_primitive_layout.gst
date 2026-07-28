// Phase 14.2 compiler-owned declared-target and primitive-scalar authority.
//
// This module is the only place that chooses the declared host target set and
// the layout of bool, fixed-width integers, and pointer-sized integers. MIR-to-C
// and Cranelift consume the resulting MirLayoutTable; they do not infer sizes or
// alignments from their host language or backend defaults.

import "mir_layout.gst" as layout;

type MirDeclaredTargetQuery[ctx] struct {
    found: int,
    target: layout.MirTargetLayout[ctx],
    object_format: str
}

func mir_primitive_layout_normalize_target_triple(target_triple: str, ctx: &Arena) str {
    if std.str_eq(target_triple, "x86_64-unknown-linux-gnu") == 1 ||
       std.str_eq(target_triple, "x86_64-linux") == 1
    {
        return std.Clone(ctx, "x86_64-unknown-linux-gnu");
    }
    if std.str_eq(target_triple, "aarch64-unknown-linux-gnu") == 1 ||
       std.str_eq(target_triple, "aarch64-linux") == 1
    {
        return std.Clone(ctx, "aarch64-unknown-linux-gnu");
    }
    if std.str_eq(target_triple, "i686-unknown-linux-gnu") == 1 ||
       std.str_eq(target_triple, "i686-linux") == 1
    {
        return std.Clone(ctx, "i686-unknown-linux-gnu");
    }
    if std.str_eq(target_triple, "x86_64-apple-darwin") == 1 ||
       std.str_eq(target_triple, "x86_64-darwin") == 1
    {
        return std.Clone(ctx, "x86_64-apple-darwin");
    }
    if std.str_eq(target_triple, "aarch64-apple-darwin") == 1 ||
       std.str_eq(target_triple, "aarch64-darwin") == 1
    {
        return std.Clone(ctx, "aarch64-apple-darwin");
    }
    return std.Clone(ctx, "");
}

func mir_primitive_layout_target_identity(target_triple: str, endianness: str, pointer_size: int, pointer_alignment: int, i32_alignment: int, i64_alignment: int, max_aggregate_alignment: int, ctx: &Arena) str {
    mut identity := "target:v1:triple=";
    identity = std.Concat(identity, target_triple);
    identity = std.Concat(identity, ":endian=");
    identity = std.Concat(identity, endianness);
    identity = std.Concat(identity, ":ptr_size=");
    identity = std.Concat(identity, std.FormatInt(pointer_size));
    identity = std.Concat(identity, ":ptr_align=");
    identity = std.Concat(identity, std.FormatInt(pointer_alignment));
    identity = std.Concat(identity, ":i32_align=");
    identity = std.Concat(identity, std.FormatInt(i32_alignment));
    identity = std.Concat(identity, ":i64_align=");
    identity = std.Concat(identity, std.FormatInt(i64_alignment));
    identity = std.Concat(identity, ":max_align=");
    identity = std.Concat(identity, std.FormatInt(max_aggregate_alignment));
    return std.Clone(ctx, identity);
}

func mir_primitive_layout_make_declared_target(target_triple: str, endianness: str, pointer_size: int, pointer_alignment: int, i32_alignment: int, i64_alignment: int, max_aggregate_alignment: int, object_format: str, ctx: &Arena) MirDeclaredTargetQuery[ctx] {
    mut result: MirDeclaredTargetQuery[ctx];
    result.found = 1;
    mut target_id := mir_primitive_layout_target_identity(
        target_triple,
        endianness,
        pointer_size,
        pointer_alignment,
        i32_alignment,
        i64_alignment,
        max_aggregate_alignment,
        ctx
    );
    result.target = layout.mir_layout_make_target_v2(
        target_id,
        target_triple,
        endianness,
        pointer_size,
        pointer_alignment,
        i32_alignment,
        i64_alignment,
        max_aggregate_alignment,
        ctx
    );
    result.object_format = std.Clone(ctx, object_format);
    return result;
}

func mir_primitive_layout_target(target_triple: str, ctx: &Arena) MirDeclaredTargetQuery[ctx] {
    mut result: MirDeclaredTargetQuery[ctx];
    result.found = 0;
    result.object_format = std.Clone(ctx, "");
    mut normalized := mir_primitive_layout_normalize_target_triple(
        target_triple,
        ctx
    );
    if len(normalized) == 0 {
        return result;
    }
    if std.str_eq(normalized, "i686-unknown-linux-gnu") == 1 {
        return mir_primitive_layout_make_declared_target(
            normalized,
            "little",
            4,
            4,
            4,
            4,
            4,
            "Elf",
            ctx
        );
    }
    if std.str_eq(normalized, "x86_64-unknown-linux-gnu") == 1 ||
       std.str_eq(normalized, "aarch64-unknown-linux-gnu") == 1
    {
        return mir_primitive_layout_make_declared_target(
            normalized,
            "little",
            8,
            8,
            4,
            8,
            8,
            "Elf",
            ctx
        );
    }
    return mir_primitive_layout_make_declared_target(
        normalized,
        "little",
        8,
        8,
        4,
        8,
        8,
        "MachO",
        ctx
    );
}

func mir_primitive_layout_declared_target_triples(ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut targets: std.Vector[str, ctx] := std.VectorNew(ctx);
    targets.Push(std.Clone(ctx, "x86_64-unknown-linux-gnu"));
    targets.Push(std.Clone(ctx, "aarch64-unknown-linux-gnu"));
    targets.Push(std.Clone(ctx, "i686-unknown-linux-gnu"));
    targets.Push(std.Clone(ctx, "x86_64-apple-darwin"));
    targets.Push(std.Clone(ctx, "aarch64-apple-darwin"));
    mut targets_idx: Index[std.Vector[str, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(targets_idx, targets);
    return targets_idx;
}

func mir_primitive_layout_primary_level2_target(ctx: &Arena) str {
    return std.Clone(ctx, "x86_64-unknown-linux-gnu");
}

func mir_primitive_layout_table_for_target(target_triple: str, ctx: &Arena) layout.MirLayoutTable[ctx] {
    mut target_query := mir_primitive_layout_target(target_triple, ctx);
    if target_query.found == 0 {
        return layout.mir_layout_make_unfrozen_table(target_triple, ctx);
    }

    mut table := layout.mir_layout_make_table(target_query.target, ctx);
    table = layout.mir_layout_table_with_layout(
        table,
        layout.mir_layout_make_scalar_type_layout(
            "type:gust:bool",
            target_query.target.target_id,
            "scalar_bool",
            1,
            1,
            8,
            "not_applicable",
            "canonical_bool_0_or_1",
            ctx
        ),
        ctx
    );
    table = layout.mir_layout_table_with_layout(
        table,
        layout.mir_layout_make_scalar_type_layout(
            "type:gust:i32",
            target_query.target.target_id,
            "scalar_integer",
            4,
            target_query.target.i32_alignment,
            32,
            "signed",
            "any_bit_pattern",
            ctx
        ),
        ctx
    );
    table = layout.mir_layout_table_with_layout(
        table,
        layout.mir_layout_make_scalar_type_layout(
            "type:gust:u32",
            target_query.target.target_id,
            "scalar_integer",
            4,
            target_query.target.i32_alignment,
            32,
            "unsigned",
            "any_bit_pattern",
            ctx
        ),
        ctx
    );
    table = layout.mir_layout_table_with_layout(
        table,
        layout.mir_layout_make_scalar_type_layout(
            "type:gust:i64",
            target_query.target.target_id,
            "scalar_integer",
            8,
            target_query.target.i64_alignment,
            64,
            "signed",
            "any_bit_pattern",
            ctx
        ),
        ctx
    );
    table = layout.mir_layout_table_with_layout(
        table,
        layout.mir_layout_make_scalar_type_layout(
            "type:gust:u64",
            target_query.target.target_id,
            "scalar_integer",
            8,
            target_query.target.i64_alignment,
            64,
            "unsigned",
            "any_bit_pattern",
            ctx
        ),
        ctx
    );
    table = layout.mir_layout_table_with_layout(
        table,
        layout.mir_layout_make_scalar_type_layout(
            "type:gust:isize",
            target_query.target.target_id,
            "scalar_pointer_sized_integer",
            target_query.target.pointer_size,
            target_query.target.pointer_alignment,
            target_query.target.pointer_size * 8,
            "signed",
            "any_bit_pattern",
            ctx
        ),
        ctx
    );
    table = layout.mir_layout_table_with_layout(
        table,
        layout.mir_layout_make_scalar_type_layout(
            "type:gust:usize",
            target_query.target.target_id,
            "scalar_pointer_sized_integer",
            target_query.target.pointer_size,
            target_query.target.pointer_alignment,
            target_query.target.pointer_size * 8,
            "unsigned",
            "any_bit_pattern",
            ctx
        ),
        ctx
    );
    return table;
}

func mir_primitive_layout_append_line(output: str, line: str, ctx: &Arena) str {
    mut updated := std.Concat(output, line);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_primitive_layout_witness(table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if layout.mir_layout_table_is_valid(table, ctx) == 0 ||
       std.str_eq(table.format, "gust.compiler_layout_table.v2") == 0
    {
        return std.Clone(ctx, "primitive_layout_status: invalid\n");
    }
    mut output := "primitive_layout_status: valid\n";
    output = mir_primitive_layout_append_line(output, std.Concat("target_id: ", table.target.target_id), ctx);
    output = mir_primitive_layout_append_line(output, std.Concat("target_triple: ", table.target.target_triple), ctx);
    output = mir_primitive_layout_append_line(output, std.Concat("endianness: ", table.target.endianness), ctx);
    output = mir_primitive_layout_append_line(output, std.Concat("pointer_size: ", std.FormatInt(table.target.pointer_size)), ctx);
    output = mir_primitive_layout_append_line(output, std.Concat("pointer_alignment: ", std.FormatInt(table.target.pointer_alignment)), ctx);
    output = mir_primitive_layout_append_line(output, std.Concat("i32_alignment: ", std.FormatInt(table.target.i32_alignment)), ctx);
    output = mir_primitive_layout_append_line(output, std.Concat("i64_alignment: ", std.FormatInt(table.target.i64_alignment)), ctx);
    output = mir_primitive_layout_append_line(output, std.Concat("max_aggregate_alignment: ", std.FormatInt(table.target.max_aggregate_alignment)), ctx);

    mut layouts: std.Vector[layout.MirTypeLayout[ctx], ctx] := ctx[table.layouts];
    mut layout_index := 0;
    while layout_index < len(layouts) {
        mut item := layouts[layout_index];
        mut line := "primitive: ";
        line = std.Concat(line, item.type_id);
        line = std.Concat(line, " size=");
        line = std.Concat(line, std.FormatInt(item.size));
        line = std.Concat(line, " alignment=");
        line = std.Concat(line, std.FormatInt(item.alignment));
        line = std.Concat(line, " bit_width=");
        line = std.Concat(line, std.FormatInt(item.bit_width));
        line = std.Concat(line, " signedness=");
        line = std.Concat(line, item.signedness);
        line = std.Concat(line, " validity=");
        line = std.Concat(line, item.validity_kind);
        output = mir_primitive_layout_append_line(output, line, ctx);
        layout_index = layout_index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_primitive_layout_c_type(type_id: str, ctx: &Arena) str {
    if std.str_eq(type_id, "type:gust:bool") == 1 { return std.Clone(ctx, "uint8_t"); }
    if std.str_eq(type_id, "type:gust:i32") == 1 { return std.Clone(ctx, "int32_t"); }
    if std.str_eq(type_id, "type:gust:u32") == 1 { return std.Clone(ctx, "uint32_t"); }
    if std.str_eq(type_id, "type:gust:i64") == 1 { return std.Clone(ctx, "int64_t"); }
    if std.str_eq(type_id, "type:gust:u64") == 1 { return std.Clone(ctx, "uint64_t"); }
    if std.str_eq(type_id, "type:gust:isize") == 1 { return std.Clone(ctx, "intptr_t"); }
    if std.str_eq(type_id, "type:gust:usize") == 1 { return std.Clone(ctx, "uintptr_t"); }
    return std.Clone(ctx, "void");
}

func mir_primitive_layout_c_witness_source(table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if layout.mir_layout_table_is_valid(table, ctx) == 0 {
        return std.Clone(ctx, "");
    }
    mut output := "#include <stdint.h>\n#include <stdio.h>\n\n";
    mut layouts: std.Vector[layout.MirTypeLayout[ctx], ctx] := ctx[table.layouts];
    mut layout_index := 0;
    while layout_index < len(layouts) {
        mut item := layouts[layout_index];
        mut c_type := mir_primitive_layout_c_type(item.type_id, ctx);
        mut size_assert := "_Static_assert(sizeof(";
        size_assert = std.Concat(size_assert, c_type);
        size_assert = std.Concat(size_assert, ") == ");
        size_assert = std.Concat(size_assert, std.FormatInt(item.size));
        size_assert = std.Concat(size_assert, ", \"compiler-selected primitive size mismatch\");\n");
        output = std.Concat(output, size_assert);
        mut alignment_assert := "_Static_assert(_Alignof(";
        alignment_assert = std.Concat(alignment_assert, c_type);
        alignment_assert = std.Concat(alignment_assert, ") == ");
        alignment_assert = std.Concat(alignment_assert, std.FormatInt(item.alignment));
        alignment_assert = std.Concat(alignment_assert, ", \"compiler-selected primitive alignment mismatch\");\n");
        output = std.Concat(output, alignment_assert);
        layout_index = layout_index + 1;
    }
    output = std.Concat(output, "\nint main(void) {\n");
    mut witness := mir_primitive_layout_witness(table, ctx);
    mut line_start := 0;
    mut cursor := 0;
    while cursor < len(witness) {
        if std.str_byte_at(witness, cursor) == 10 {
            mut line := std.str_slice(witness, line_start, cursor);
            output = std.Concat(output, "    puts(\"");
            output = std.Concat(output, line);
            output = std.Concat(output, "\");\n");
            line_start = cursor + 1;
        }
        cursor = cursor + 1;
    }
    output = std.Concat(output, "    return 0;\n}\n");
    return std.Clone(ctx, output);
}