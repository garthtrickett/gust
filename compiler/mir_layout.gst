// Phase 14 compiler-owned type, target, and memory-layout authority.
//
// This module is the sole semantic owner for request-local layout decisions.
// Canonical MIR, MIR-to-C adapters, native requests, runtime descriptors, and
// diagnostics consume these records. They must not independently calculate or
// guess sizes, alignments, offsets, strides, tags, or access widths.
//
// Patch 14.1 establishes authority and transport only. The production request
// path carries an empty, unfrozen table until later Phase 14 patches select and
// migrate concrete type and memory capabilities.

type MirTargetLayout[ctx] struct {
    target_id: str,
    target_triple: str,
    pointer_size: int,
    pointer_alignment: int,
    decisions_frozen: int
}

type MirFieldLayout[ctx] struct {
    field_id: str,
    field_name: str,
    type_id: str,
    layout_id: str,
    offset: int,
    size: int,
    alignment: int
}

type MirVariantLayout[ctx] struct {
    variant_id: str,
    variant_name: str,
    discriminant: int,
    payload_layout_id: str,
    tag_offset: int,
    payload_offset: int
}

type MirTypeLayout[ctx] struct {
    layout_id: str,
    type_id: str,
    target_id: str,
    representation_kind: str,
    size: int,
    alignment: int,
    element_stride: int,
    fields: Index[std.Vector[MirFieldLayout[ctx], ctx], ctx],
    variants: Index[std.Vector[MirVariantLayout[ctx], ctx], ctx]
}

type MirMemoryAccessLayout[ctx] struct {
    access_id: str,
    type_id: str,
    layout_id: str,
    target_id: str,
    byte_width: int,
    required_alignment: int,
    write_allowed: int,
    nullable: int
}

type MirLayoutTable[ctx] struct {
    format: str,
    target: MirTargetLayout[ctx],
    layouts: Index[std.Vector[MirTypeLayout[ctx], ctx], ctx],
    memory_accesses: Index[std.Vector[MirMemoryAccessLayout[ctx], ctx], ctx]
}

type MirTypeLayoutQuery[ctx] struct {
    found: int,
    layout: MirTypeLayout[ctx]
}

type MirFieldLayoutQuery[ctx] struct {
    found: int,
    field: MirFieldLayout[ctx]
}

type MirVariantLayoutQuery[ctx] struct {
    found: int,
    variant: MirVariantLayout[ctx]
}

type MirElementStrideQuery struct {
    found: int,
    stride: int
}

type MirMemoryAccessValidation[ctx] struct {
    valid: int,
    reason_code: str
}

func mir_layout_field_is_safe(value: str, allow_empty: int) int {
    if allow_empty == 0 && len(value) == 0 {
        return 0;
    }
    if std.str_find(value, "\n") != 0 - 1 {
        return 0;
    }
    if std.str_find(value, "\r") != 0 - 1 {
        return 0;
    }
    return 1;
}

func mir_layout_alignment_is_valid(alignment: int) int {
    if alignment <= 0 {
        return 0;
    }
    mut remaining := alignment;
    while remaining > 1 {
        mut halved := remaining / 2;
        if halved * 2 != remaining {
            return 0;
        }
        remaining = halved;
    }
    return 1;
}

func mir_layout_empty_field_vector(ctx: &Arena) Index[std.Vector[MirFieldLayout[ctx], ctx], ctx] {
    mut fields: std.Vector[MirFieldLayout[ctx], ctx] := std.VectorNew(ctx);
    mut fields_idx: Index[std.Vector[MirFieldLayout[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(fields_idx, fields);
    return fields_idx;
}

func mir_layout_empty_variant_vector(ctx: &Arena) Index[std.Vector[MirVariantLayout[ctx], ctx], ctx] {
    mut variants: std.Vector[MirVariantLayout[ctx], ctx] := std.VectorNew(ctx);
    mut variants_idx: Index[std.Vector[MirVariantLayout[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(variants_idx, variants);
    return variants_idx;
}

func mir_layout_empty_type_layout_vector(ctx: &Arena) Index[std.Vector[MirTypeLayout[ctx], ctx], ctx] {
    mut layouts: std.Vector[MirTypeLayout[ctx], ctx] := std.VectorNew(ctx);
    mut layouts_idx: Index[std.Vector[MirTypeLayout[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(layouts_idx, layouts);
    return layouts_idx;
}

func mir_layout_empty_memory_access_vector(ctx: &Arena) Index[std.Vector[MirMemoryAccessLayout[ctx], ctx], ctx] {
    mut accesses: std.Vector[MirMemoryAccessLayout[ctx], ctx] := std.VectorNew(ctx);
    mut accesses_idx: Index[std.Vector[MirMemoryAccessLayout[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(accesses_idx, accesses);
    return accesses_idx;
}

func mir_layout_make_target(target_id: str, target_triple: str, pointer_size: int, pointer_alignment: int, decisions_frozen: int, ctx: &Arena) MirTargetLayout[ctx] {
    mut target: MirTargetLayout[ctx];
    target.target_id = std.Clone(ctx, target_id);
    target.target_triple = std.Clone(ctx, target_triple);
    target.pointer_size = pointer_size;
    target.pointer_alignment = pointer_alignment;
    target.decisions_frozen = decisions_frozen;
    return target;
}

func mir_layout_make_unfrozen_table(target_triple: str, ctx: &Arena) MirLayoutTable[ctx] {
    mut target_id := std.Concat("phase14-target:unfrozen:", target_triple);
    mut table: MirLayoutTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_layout_table.v1");
    table.target = mir_layout_make_target(
        target_id,
        target_triple,
        0,
        0,
        0,
        ctx
    );
    table.layouts = mir_layout_empty_type_layout_vector(ctx);
    table.memory_accesses = mir_layout_empty_memory_access_vector(ctx);
    return table;
}

func mir_layout_make_table(target: MirTargetLayout[ctx], ctx: &Arena) MirLayoutTable[ctx] {
    mut table: MirLayoutTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_layout_table.v1");
    table.target = target;
    table.layouts = mir_layout_empty_type_layout_vector(ctx);
    table.memory_accesses = mir_layout_empty_memory_access_vector(ctx);
    return table;
}

func mir_layout_identity(type_id: str, target_id: str, representation_kind: str, size: int, alignment: int, element_stride: int, ctx: &Arena) str {
    mut identity := "layout:v1:type=";
    identity = std.Concat(identity, type_id);
    identity = std.Concat(identity, ":target=");
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":kind=");
    identity = std.Concat(identity, representation_kind);
    identity = std.Concat(identity, ":size=");
    identity = std.Concat(identity, std.FormatInt(size));
    identity = std.Concat(identity, ":align=");
    identity = std.Concat(identity, std.FormatInt(alignment));
    identity = std.Concat(identity, ":stride=");
    identity = std.Concat(identity, std.FormatInt(element_stride));
    return std.Clone(ctx, identity);
}

func mir_layout_make_type_layout(type_id: str, target_id: str, representation_kind: str, size: int, alignment: int, element_stride: int, ctx: &Arena) MirTypeLayout[ctx] {
    mut layout: MirTypeLayout[ctx];
    layout.layout_id = mir_layout_identity(
        type_id,
        target_id,
        representation_kind,
        size,
        alignment,
        element_stride,
        ctx
    );
    layout.type_id = std.Clone(ctx, type_id);
    layout.target_id = std.Clone(ctx, target_id);
    layout.representation_kind = std.Clone(ctx, representation_kind);
    layout.size = size;
    layout.alignment = alignment;
    layout.element_stride = element_stride;
    layout.fields = mir_layout_empty_field_vector(ctx);
    layout.variants = mir_layout_empty_variant_vector(ctx);
    return layout;
}

func mir_layout_make_field(field_id: str, field_name: str, type_id: str, layout_id: str, offset: int, size: int, alignment: int, ctx: &Arena) MirFieldLayout[ctx] {
    mut field: MirFieldLayout[ctx];
    field.field_id = std.Clone(ctx, field_id);
    field.field_name = std.Clone(ctx, field_name);
    field.type_id = std.Clone(ctx, type_id);
    field.layout_id = std.Clone(ctx, layout_id);
    field.offset = offset;
    field.size = size;
    field.alignment = alignment;
    return field;
}

func mir_layout_make_variant(variant_id: str, variant_name: str, discriminant: int, payload_layout_id: str, tag_offset: int, payload_offset: int, ctx: &Arena) MirVariantLayout[ctx] {
    mut variant: MirVariantLayout[ctx];
    variant.variant_id = std.Clone(ctx, variant_id);
    variant.variant_name = std.Clone(ctx, variant_name);
    variant.discriminant = discriminant;
    variant.payload_layout_id = std.Clone(ctx, payload_layout_id);
    variant.tag_offset = tag_offset;
    variant.payload_offset = payload_offset;
    return variant;
}

func mir_layout_make_memory_access(access_id: str, type_id: str, layout_id: str, target_id: str, byte_width: int, required_alignment: int, write_allowed: int, nullable: int, ctx: &Arena) MirMemoryAccessLayout[ctx] {
    mut access: MirMemoryAccessLayout[ctx];
    access.access_id = std.Clone(ctx, access_id);
    access.type_id = std.Clone(ctx, type_id);
    access.layout_id = std.Clone(ctx, layout_id);
    access.target_id = std.Clone(ctx, target_id);
    access.byte_width = byte_width;
    access.required_alignment = required_alignment;
    access.write_allowed = write_allowed;
    access.nullable = nullable;
    return access;
}

func mir_layout_type_with_field(layout: MirTypeLayout[ctx], field: MirFieldLayout[ctx], ctx: &Arena) MirTypeLayout[ctx] {
    mut updated := layout;
    mut fields: std.Vector[MirFieldLayout[ctx], ctx] := ctx[updated.fields];
    fields.Push(field);
    ctx.Set(updated.fields, fields);
    return updated;
}

func mir_layout_type_with_variant(layout: MirTypeLayout[ctx], variant: MirVariantLayout[ctx], ctx: &Arena) MirTypeLayout[ctx] {
    mut updated := layout;
    mut variants: std.Vector[MirVariantLayout[ctx], ctx] := ctx[updated.variants];
    variants.Push(variant);
    ctx.Set(updated.variants, variants);
    return updated;
}

func mir_layout_table_with_layout(table: MirLayoutTable[ctx], layout: MirTypeLayout[ctx], ctx: &Arena) MirLayoutTable[ctx] {
    mut updated := table;
    mut layouts: std.Vector[MirTypeLayout[ctx], ctx] := ctx[updated.layouts];
    layouts.Push(layout);
    ctx.Set(updated.layouts, layouts);
    return updated;
}

func mir_layout_table_with_memory_access(table: MirLayoutTable[ctx], access: MirMemoryAccessLayout[ctx], ctx: &Arena) MirLayoutTable[ctx] {
    mut updated := table;
    mut accesses: std.Vector[MirMemoryAccessLayout[ctx], ctx] := ctx[updated.memory_accesses];
    accesses.Push(access);
    ctx.Set(updated.memory_accesses, accesses);
    return updated;
}

func mir_layout_table_has_layout_id(table: MirLayoutTable[ctx], layout_id: str, ctx: &Arena) int {
    mut layouts: std.Vector[MirTypeLayout[ctx], ctx] := ctx[table.layouts];
    mut layout_index := 0;
    while layout_index < len(layouts) {
        if std.str_eq(layouts[layout_index].layout_id, layout_id) == 1 {
            return 1;
        }
        layout_index = layout_index + 1;
    }
    return 0;
}

func mir_layout_table_is_valid(table: MirLayoutTable[ctx], ctx: &Arena) int {
    if std.str_eq(table.format, "gust.compiler_layout_table.v1") == 0 {
        return 0;
    }
    if mir_layout_field_is_safe(table.target.target_id, 0) == 0 {
        return 0;
    }
    if mir_layout_field_is_safe(table.target.target_triple, 0) == 0 {
        return 0;
    }
    if table.target.decisions_frozen != 0 && table.target.decisions_frozen != 1 {
        return 0;
    }

    mut layouts: std.Vector[MirTypeLayout[ctx], ctx] := ctx[table.layouts];
    mut accesses: std.Vector[MirMemoryAccessLayout[ctx], ctx] := ctx[table.memory_accesses];
    if table.target.decisions_frozen == 0 {
        if table.target.pointer_size != 0 || table.target.pointer_alignment != 0 {
            return 0;
        }
        if len(layouts) != 0 || len(accesses) != 0 {
            return 0;
        }
        return 1;
    }

    if table.target.pointer_size <= 0 {
        return 0;
    }
    if mir_layout_alignment_is_valid(table.target.pointer_alignment) == 0 {
        return 0;
    }

    mut layout_index := 0;
    while layout_index < len(layouts) {
        mut layout := layouts[layout_index];
        if mir_layout_field_is_safe(layout.layout_id, 0) == 0 ||
           mir_layout_field_is_safe(layout.type_id, 0) == 0 ||
           mir_layout_field_is_safe(layout.target_id, 0) == 0 ||
           mir_layout_field_is_safe(layout.representation_kind, 0) == 0
        {
            return 0;
        }
        if std.str_eq(layout.target_id, table.target.target_id) == 0 {
            return 0;
        }
        if layout.size < 0 || layout.element_stride < 0 {
            return 0;
        }
        if mir_layout_alignment_is_valid(layout.alignment) == 0 {
            return 0;
        }
        if layout.element_stride != 0 && layout.element_stride < layout.size {
            return 0;
        }
        mut expected_id := mir_layout_identity(
            layout.type_id,
            layout.target_id,
            layout.representation_kind,
            layout.size,
            layout.alignment,
            layout.element_stride,
            ctx
        );
        if std.str_eq(layout.layout_id, expected_id) == 0 {
            return 0;
        }

        mut prior_layout_index := 0;
        while prior_layout_index < layout_index {
            if std.str_eq(
                layouts[prior_layout_index].layout_id,
                layout.layout_id
            ) == 1 {
                return 0;
            }
            prior_layout_index = prior_layout_index + 1;
        }

        mut fields: std.Vector[MirFieldLayout[ctx], ctx] := ctx[layout.fields];
        mut field_index := 0;
        while field_index < len(fields) {
            mut field := fields[field_index];
            if mir_layout_field_is_safe(field.field_id, 0) == 0 ||
               mir_layout_field_is_safe(field.field_name, 0) == 0 ||
               mir_layout_field_is_safe(field.type_id, 0) == 0 ||
               mir_layout_field_is_safe(field.layout_id, 0) == 0
            {
                return 0;
            }
            if field.offset < 0 || field.size < 0 {
                return 0;
            }
            if mir_layout_alignment_is_valid(field.alignment) == 0 {
                return 0;
            }
            if field.offset + field.size > layout.size {
                return 0;
            }
            if field.offset / field.alignment * field.alignment != field.offset {
                return 0;
            }
            if mir_layout_table_has_layout_id(table, field.layout_id, ctx) == 0 {
                return 0;
            }
            mut prior_field_index := 0;
            while prior_field_index < field_index {
                if std.str_eq(fields[prior_field_index].field_id, field.field_id) == 1 ||
                   std.str_eq(fields[prior_field_index].field_name, field.field_name) == 1
                {
                    return 0;
                }
                prior_field_index = prior_field_index + 1;
            }
            field_index = field_index + 1;
        }

        mut variants: std.Vector[MirVariantLayout[ctx], ctx] := ctx[layout.variants];
        mut variant_index := 0;
        while variant_index < len(variants) {
            mut variant := variants[variant_index];
            if mir_layout_field_is_safe(variant.variant_id, 0) == 0 ||
               mir_layout_field_is_safe(variant.variant_name, 0) == 0 ||
               mir_layout_field_is_safe(variant.payload_layout_id, 1) == 0
            {
                return 0;
            }
            if variant.tag_offset < 0 || variant.payload_offset < 0 {
                return 0;
            }
            if variant.tag_offset >= layout.size || variant.payload_offset > layout.size {
                return 0;
            }
            if len(variant.payload_layout_id) != 0 &&
               mir_layout_table_has_layout_id(table, variant.payload_layout_id, ctx) == 0
            {
                return 0;
            }
            mut prior_variant_index := 0;
            while prior_variant_index < variant_index {
                mut prior_variant := variants[prior_variant_index];
                if std.str_eq(prior_variant.variant_id, variant.variant_id) == 1 ||
                   std.str_eq(prior_variant.variant_name, variant.variant_name) == 1 ||
                   prior_variant.discriminant == variant.discriminant
                {
                    return 0;
                }
                prior_variant_index = prior_variant_index + 1;
            }
            variant_index = variant_index + 1;
        }

        layout_index = layout_index + 1;
    }

    mut access_index := 0;
    while access_index < len(accesses) {
        mut access := accesses[access_index];
        if mir_layout_field_is_safe(access.access_id, 0) == 0 ||
           mir_layout_field_is_safe(access.type_id, 0) == 0 ||
           mir_layout_field_is_safe(access.layout_id, 0) == 0 ||
           mir_layout_field_is_safe(access.target_id, 0) == 0
        {
            return 0;
        }
        if std.str_eq(access.target_id, table.target.target_id) == 0 {
            return 0;
        }
        if access.byte_width <= 0 ||
           mir_layout_alignment_is_valid(access.required_alignment) == 0
        {
            return 0;
        }
        if access.write_allowed < 0 || access.write_allowed > 1 ||
           access.nullable < 0 || access.nullable > 1
        {
            return 0;
        }
        if mir_layout_table_has_layout_id(table, access.layout_id, ctx) == 0 {
            return 0;
        }
        mut prior_access_index := 0;
        while prior_access_index < access_index {
            if std.str_eq(
                accesses[prior_access_index].access_id,
                access.access_id
            ) == 1 {
                return 0;
            }
            prior_access_index = prior_access_index + 1;
        }
        access_index = access_index + 1;
    }

    return 1;
}

func mir_layout_of(table: MirLayoutTable[ctx], type_id: str, target_id: str, ctx: &Arena) MirTypeLayoutQuery[ctx] {
    mut result: MirTypeLayoutQuery[ctx];
    result.found = 0;
    mut layouts: std.Vector[MirTypeLayout[ctx], ctx] := ctx[table.layouts];
    mut layout_index := 0;
    while layout_index < len(layouts) {
        mut layout := layouts[layout_index];
        if std.str_eq(layout.type_id, type_id) == 1 &&
           std.str_eq(layout.target_id, target_id) == 1
        {
            result.found = 1;
            result.layout = layout;
            return result;
        }
        layout_index = layout_index + 1;
    }
    return result;
}

func mir_layout_field_layout(table: MirLayoutTable[ctx], type_id: str, field_name: str, target_id: str, ctx: &Arena) MirFieldLayoutQuery[ctx] {
    mut result: MirFieldLayoutQuery[ctx];
    result.found = 0;
    mut type_result := mir_layout_of(table, type_id, target_id, ctx);
    if type_result.found == 0 {
        return result;
    }
    mut fields: std.Vector[MirFieldLayout[ctx], ctx] := ctx[type_result.layout.fields];
    mut field_index := 0;
    while field_index < len(fields) {
        if std.str_eq(fields[field_index].field_name, field_name) == 1 {
            result.found = 1;
            result.field = fields[field_index];
            return result;
        }
        field_index = field_index + 1;
    }
    return result;
}

func mir_layout_variant_layout(table: MirLayoutTable[ctx], type_id: str, variant_name: str, target_id: str, ctx: &Arena) MirVariantLayoutQuery[ctx] {
    mut result: MirVariantLayoutQuery[ctx];
    result.found = 0;
    mut type_result := mir_layout_of(table, type_id, target_id, ctx);
    if type_result.found == 0 {
        return result;
    }
    mut variants: std.Vector[MirVariantLayout[ctx], ctx] := ctx[type_result.layout.variants];
    mut variant_index := 0;
    while variant_index < len(variants) {
        if std.str_eq(variants[variant_index].variant_name, variant_name) == 1 {
            result.found = 1;
            result.variant = variants[variant_index];
            return result;
        }
        variant_index = variant_index + 1;
    }
    return result;
}

func mir_layout_element_stride(table: MirLayoutTable[ctx], type_id: str, target_id: str, ctx: &Arena) MirElementStrideQuery {
    mut result: MirElementStrideQuery;
    result.found = 0;
    result.stride = 0;
    mut type_result := mir_layout_of(table, type_id, target_id, ctx);
    if type_result.found == 1 {
        result.found = 1;
        result.stride = type_result.layout.element_stride;
    }
    return result;
}

func mir_layout_validate_memory_access(table: MirLayoutTable[ctx], type_id: str, byte_width: int, alignment: int, target_id: str, ctx: &Arena) MirMemoryAccessValidation[ctx] {
    mut result: MirMemoryAccessValidation[ctx];
    result.valid = 0;
    result.reason_code = "layout_access_not_declared";
    if mir_layout_table_is_valid(table, ctx) == 0 {
        result.reason_code = "layout_table_invalid";
        return result;
    }
    mut accesses: std.Vector[MirMemoryAccessLayout[ctx], ctx] := ctx[table.memory_accesses];
    mut access_index := 0;
    while access_index < len(accesses) {
        mut access := accesses[access_index];
        if std.str_eq(access.type_id, type_id) == 1 &&
           std.str_eq(access.target_id, target_id) == 1
        {
            if access.byte_width != byte_width {
                result.reason_code = "layout_access_width_mismatch";
                return result;
            }
            if access.required_alignment != alignment {
                result.reason_code = "layout_access_alignment_mismatch";
                return result;
            }
            result.valid = 1;
            result.reason_code = "layout_access_valid";
            return result;
        }
        access_index = access_index + 1;
    }
    return result;
}

func mir_layout_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_serialize_layout_table_for_request(table: MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_layout_table_is_valid(table, ctx) == 0 {
        return "layout_table_format: invalid\n";
    }

    mut output := "";
    output = mir_layout_append_field(output, "layout_table_format", table.format, ctx);
    output = mir_layout_append_field(output, "layout_target_id", table.target.target_id, ctx);
    output = mir_layout_append_field(output, "layout_target_triple", table.target.target_triple, ctx);
    output = mir_layout_append_field(output, "layout_target_pointer_size", std.FormatInt(table.target.pointer_size), ctx);
    output = mir_layout_append_field(output, "layout_target_pointer_alignment", std.FormatInt(table.target.pointer_alignment), ctx);
    output = mir_layout_append_field(output, "layout_target_decisions_frozen", std.FormatInt(table.target.decisions_frozen), ctx);

    mut layouts: std.Vector[MirTypeLayout[ctx], ctx] := ctx[table.layouts];
    output = mir_layout_append_field(output, "layout_count", std.FormatInt(len(layouts)), ctx);
    mut layout_index := 0;
    while layout_index < len(layouts) {
        mut layout := layouts[layout_index];
        mut prefix := std.Concat("layout_", std.FormatInt(layout_index));
        output = mir_layout_append_field(output, std.Concat(prefix, "_id"), layout.layout_id, ctx);
        output = mir_layout_append_field(output, std.Concat(prefix, "_type_id"), layout.type_id, ctx);
        output = mir_layout_append_field(output, std.Concat(prefix, "_target_id"), layout.target_id, ctx);
        output = mir_layout_append_field(output, std.Concat(prefix, "_kind"), layout.representation_kind, ctx);
        output = mir_layout_append_field(output, std.Concat(prefix, "_size"), std.FormatInt(layout.size), ctx);
        output = mir_layout_append_field(output, std.Concat(prefix, "_alignment"), std.FormatInt(layout.alignment), ctx);
        output = mir_layout_append_field(output, std.Concat(prefix, "_element_stride"), std.FormatInt(layout.element_stride), ctx);

        mut fields: std.Vector[MirFieldLayout[ctx], ctx] := ctx[layout.fields];
        output = mir_layout_append_field(output, std.Concat(prefix, "_field_count"), std.FormatInt(len(fields)), ctx);
        mut field_index := 0;
        while field_index < len(fields) {
            mut field := fields[field_index];
            mut field_prefix := std.Concat(std.Concat(prefix, "_field_"), std.FormatInt(field_index));
            output = mir_layout_append_field(output, std.Concat(field_prefix, "_id"), field.field_id, ctx);
            output = mir_layout_append_field(output, std.Concat(field_prefix, "_name"), field.field_name, ctx);
            output = mir_layout_append_field(output, std.Concat(field_prefix, "_type_id"), field.type_id, ctx);
            output = mir_layout_append_field(output, std.Concat(field_prefix, "_layout_id"), field.layout_id, ctx);
            output = mir_layout_append_field(output, std.Concat(field_prefix, "_offset"), std.FormatInt(field.offset), ctx);
            output = mir_layout_append_field(output, std.Concat(field_prefix, "_size"), std.FormatInt(field.size), ctx);
            output = mir_layout_append_field(output, std.Concat(field_prefix, "_alignment"), std.FormatInt(field.alignment), ctx);
            field_index = field_index + 1;
        }

        mut variants: std.Vector[MirVariantLayout[ctx], ctx] := ctx[layout.variants];
        output = mir_layout_append_field(output, std.Concat(prefix, "_variant_count"), std.FormatInt(len(variants)), ctx);
        mut variant_index := 0;
        while variant_index < len(variants) {
            mut variant := variants[variant_index];
            mut variant_prefix := std.Concat(std.Concat(prefix, "_variant_"), std.FormatInt(variant_index));
            output = mir_layout_append_field(output, std.Concat(variant_prefix, "_id"), variant.variant_id, ctx);
            output = mir_layout_append_field(output, std.Concat(variant_prefix, "_name"), variant.variant_name, ctx);
            output = mir_layout_append_field(output, std.Concat(variant_prefix, "_discriminant"), std.FormatInt(variant.discriminant), ctx);
            output = mir_layout_append_field(output, std.Concat(variant_prefix, "_payload_layout_id"), variant.payload_layout_id, ctx);
            output = mir_layout_append_field(output, std.Concat(variant_prefix, "_tag_offset"), std.FormatInt(variant.tag_offset), ctx);
            output = mir_layout_append_field(output, std.Concat(variant_prefix, "_payload_offset"), std.FormatInt(variant.payload_offset), ctx);
            variant_index = variant_index + 1;
        }
        layout_index = layout_index + 1;
    }

    mut accesses: std.Vector[MirMemoryAccessLayout[ctx], ctx] := ctx[table.memory_accesses];
    output = mir_layout_append_field(output, "memory_access_count", std.FormatInt(len(accesses)), ctx);
    mut access_index := 0;
    while access_index < len(accesses) {
        mut access := accesses[access_index];
        mut prefix := std.Concat("memory_access_", std.FormatInt(access_index));
        output = mir_layout_append_field(output, std.Concat(prefix, "_id"), access.access_id, ctx);
        output = mir_layout_append_field(output, std.Concat(prefix, "_type_id"), access.type_id, ctx);
        output = mir_layout_append_field(output, std.Concat(prefix, "_layout_id"), access.layout_id, ctx);
        output = mir_layout_append_field(output, std.Concat(prefix, "_target_id"), access.target_id, ctx);
        output = mir_layout_append_field(output, std.Concat(prefix, "_byte_width"), std.FormatInt(access.byte_width), ctx);
        output = mir_layout_append_field(output, std.Concat(prefix, "_required_alignment"), std.FormatInt(access.required_alignment), ctx);
        output = mir_layout_append_field(output, std.Concat(prefix, "_write_allowed"), std.FormatInt(access.write_allowed), ctx);
        output = mir_layout_append_field(output, std.Concat(prefix, "_nullable"), std.FormatInt(access.nullable), ctx);
        access_index = access_index + 1;
    }
    return std.Clone(ctx, output);
}