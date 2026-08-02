// Phase 14.10 compiler-owned enum and tagged-union authority.
//
// Selected enums use an explicit tag-and-payload representation. The compiler
// owns tag type selection, tag width, tag offset, the valid discriminant set,
// the shared payload offset, the maximum payload size and alignment, and the
// total enum size and alignment. Consumers validate and execute that decision
// without recomputing it.
//
// Niche optimization stays deferred: the tag is always stored explicitly at a
// compiler-selected offset. Struct payloads are not part of this patch's
// inventory; selected aggregate payloads reuse the stable Patch 14.8
// fixed-array authority, and Patch 14.9 owns struct layout itself.

import "mir_layout.gst" as layout;
import "mir_array_slice.gst" as array_slice;

type MirEnumVariant[ctx] struct {
    variant_id: str,
    variant_name: str,
    enum_type_id: str,
    declaration_index: int,
    discriminant: int,
    has_payload: int,
    payload_type_id: str,
    payload_layout_id: str,
    payload_element_type_id: str,
    payload_element_count: int,
    payload_element_stride: int,
    payload_size: int,
    payload_alignment: int
}

type MirEnumLayout[ctx] struct {
    enum_type_id: str,
    layout_id: str,
    target_id: str,
    target_triple: str,
    tag_type_id: str,
    tag_layout_id: str,
    tag_width: int,
    tag_alignment: int,
    tag_offset: int,
    discriminant_assignment: str,
    variant_count: int,
    payload_offset: int,
    max_payload_size: int,
    max_payload_alignment: int,
    size: int,
    alignment: int,
    representation_kind: str,
    variants: Index[std.Vector[MirEnumVariant[ctx], ctx], ctx]
}

type MirEnumValue[ctx] struct {
    value_id: str,
    enum_layout_id: str,
    enum_type_id: str,
    variant_name: str,
    discriminant: int,
    payload_values: Index[std.Vector[int, ctx], ctx],
    storage_region: str,
    flow_origin: str
}

type MirEnumOperation[ctx] struct {
    operation_id: str,
    operation_name: str,
    target_id: str,
    kind: str,
    value_id: str,
    variant_name: str,
    payload_index: int,
    expect_success: int,
    expected_value: int,
    expected_offset: int,
    expected_tag: int,
    expected_arm_index: int,
    expected_reason_code: str
}

type MirEnumTable[ctx] struct {
    format: str,
    target_id: str,
    target_triple: str,
    tag_authority: str,
    discriminant_policy: str,
    payload_policy: str,
    niche_policy: str,
    match_policy: str,
    struct_payload_policy: str,
    layouts: Index[std.Vector[MirEnumLayout[ctx], ctx], ctx],
    values: Index[std.Vector[MirEnumValue[ctx], ctx], ctx],
    operations: Index[std.Vector[MirEnumOperation[ctx], ctx], ctx]
}

type MirEnumLayoutQuery[ctx] struct {
    found: int,
    enum_layout: MirEnumLayout[ctx]
}

type MirEnumVariantQuery[ctx] struct {
    found: int,
    variant: MirEnumVariant[ctx]
}

type MirEnumValueQuery[ctx] struct {
    found: int,
    enum_value: MirEnumValue[ctx]
}

type MirEnumOperationQuery[ctx] struct {
    found: int,
    operation: MirEnumOperation[ctx]
}

type MirEnumEvaluation[ctx] struct {
    success: int,
    value: int,
    offset: int,
    tag: int,
    arm_index: int,
    reason_code: str
}

func mir_enum_empty_variant_vector(ctx: &Arena) Index[std.Vector[MirEnumVariant[ctx], ctx], ctx] {
    mut values: std.Vector[MirEnumVariant[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirEnumVariant[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_enum_empty_layout_vector(ctx: &Arena) Index[std.Vector[MirEnumLayout[ctx], ctx], ctx] {
    mut values: std.Vector[MirEnumLayout[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirEnumLayout[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_enum_empty_value_vector(ctx: &Arena) Index[std.Vector[MirEnumValue[ctx], ctx], ctx] {
    mut values: std.Vector[MirEnumValue[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirEnumValue[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_enum_empty_operation_vector(ctx: &Arena) Index[std.Vector[MirEnumOperation[ctx], ctx], ctx] {
    mut values: std.Vector[MirEnumOperation[ctx], ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[MirEnumOperation[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_enum_empty_int_vector(ctx: &Arena) Index[std.Vector[int, ctx], ctx] {
    mut values: std.Vector[int, ctx] := std.VectorNew(ctx);
    mut values_idx: Index[std.Vector[int, ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(values_idx, values);
    return values_idx;
}

func mir_enum_make_empty_table(target_triple: str, ctx: &Arena) MirEnumTable[ctx] {
    mut table: MirEnumTable[ctx];
    table.format = std.Clone(ctx, "gust.compiler_enum_table.v1");
    table.target_id = std.Clone(ctx, "");
    table.target_triple = std.Clone(ctx, target_triple);
    table.tag_authority = std.Clone(ctx, "compiler_owned_tag_selection_no_backend_inference");
    table.discriminant_policy = std.Clone(ctx, "explicit_or_compiler_assigned_unique_discriminants");
    table.payload_policy = std.Clone(ctx, "explicit_tag_with_shared_payload_offset");
    table.niche_policy = std.Clone(ctx, "deferred_niche_optimization");
    table.match_policy = std.Clone(ctx, "checked_tag_dispatch_over_declared_variants");
    table.struct_payload_policy = std.Clone(ctx, "deferred_struct_payloads_not_selected_by_patch14_10");
    table.layouts = mir_enum_empty_layout_vector(ctx);
    table.values = mir_enum_empty_value_vector(ctx);
    table.operations = mir_enum_empty_operation_vector(ctx);
    return table;
}

func mir_enum_table_is_legacy_empty(table: MirEnumTable[ctx], ctx: &Arena) int {
    mut layouts: std.Vector[MirEnumLayout[ctx], ctx] := ctx[table.layouts];
    mut values: std.Vector[MirEnumValue[ctx], ctx] := ctx[table.values];
    mut operations: std.Vector[MirEnumOperation[ctx], ctx] := ctx[table.operations];
    if len(table.target_id) == 0 &&
       len(layouts) == 0 && len(values) == 0 && len(operations) == 0
    {
        return 1;
    }
    return 0;
}

func mir_enum_field_is_safe(value: str, allow_empty: int) int {
    if allow_empty == 0 && len(value) == 0 { return 0; }
    if std.str_find(value, "\n") != 0 - 1 { return 0; }
    if std.str_find(value, "\r") != 0 - 1 { return 0; }
    return 1;
}

func mir_enum_align_up(value: int, alignment: int) int {
    if alignment <= 0 { return 0; }
    mut quotient := value / alignment;
    mut remainder := value - quotient * alignment;
    if remainder == 0 { return value; }
    return value + alignment - remainder;
}

func mir_enum_operation_kind_is_valid(kind: str) int {
    if std.str_eq(kind, "variant_construct") == 1 { return 1; }
    if std.str_eq(kind, "tag_read") == 1 { return 1; }
    if std.str_eq(kind, "variant_test") == 1 { return 1; }
    if std.str_eq(kind, "payload_project") == 1 { return 1; }
    if std.str_eq(kind, "match_branch") == 1 { return 1; }
    return 0;
}

// Compiler-owned tag selection. The narrowest declared unsigned tag that holds
// every discriminant wins; anything wider than the selected inventory stays
// rejected rather than silently widened.
func mir_enum_select_tag_type_id(max_discriminant: int) str {
    if max_discriminant <= 255 { return "type:gust:u8"; }
    return "type:gust:i32";
}

func mir_enum_tag_capacity(tag_type_id: str) int {
    if std.str_eq(tag_type_id, "type:gust:u8") == 1 { return 255; }
    return 2147483647;
}

func mir_enum_variant_identity(enum_type_id: str, variant_name: str, declaration_index: int, discriminant: int, ctx: &Arena) str {
    mut identity := "enum_variant:v1:type=";
    identity = std.Concat(identity, enum_type_id);
    identity = std.Concat(identity, ":name=");
    identity = std.Concat(identity, variant_name);
    identity = std.Concat(identity, ":index=");
    identity = std.Concat(identity, std.FormatInt(declaration_index));
    identity = std.Concat(identity, ":discriminant=");
    identity = std.Concat(identity, std.FormatInt(discriminant));
    return std.Clone(ctx, identity);
}

func mir_enum_layout_identity(target_id: str, enum_type_id: str, tag_type_id: str, tag_width: int, payload_offset: int, size: int, alignment: int, variant_count: int, ctx: &Arena) str {
    mut identity := "enum_layout:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":type=");
    identity = std.Concat(identity, enum_type_id);
    identity = std.Concat(identity, ":tag=");
    identity = std.Concat(identity, tag_type_id);
    identity = std.Concat(identity, ":tag_width=");
    identity = std.Concat(identity, std.FormatInt(tag_width));
    identity = std.Concat(identity, ":payload_offset=");
    identity = std.Concat(identity, std.FormatInt(payload_offset));
    identity = std.Concat(identity, ":size=");
    identity = std.Concat(identity, std.FormatInt(size));
    identity = std.Concat(identity, ":align=");
    identity = std.Concat(identity, std.FormatInt(alignment));
    identity = std.Concat(identity, ":variants=");
    identity = std.Concat(identity, std.FormatInt(variant_count));
    return std.Clone(ctx, identity);
}

func mir_enum_operation_identity(target_id: str, operation_name: str, kind: str, ctx: &Arena) str {
    mut identity := "enum_operation:v1:target=";
    identity = std.Concat(identity, target_id);
    identity = std.Concat(identity, ":name=");
    identity = std.Concat(identity, operation_name);
    identity = std.Concat(identity, ":kind=");
    identity = std.Concat(identity, kind);
    return std.Clone(ctx, identity);
}

func mir_enum_make_fieldless_variant(enum_type_id: str, variant_name: str, declaration_index: int, discriminant: int, ctx: &Arena) MirEnumVariant[ctx] {
    mut result: MirEnumVariant[ctx];
    result.variant_name = std.Clone(ctx, variant_name);
    result.enum_type_id = std.Clone(ctx, enum_type_id);
    result.declaration_index = declaration_index;
    result.discriminant = discriminant;
    result.has_payload = 0;
    result.payload_type_id = std.Clone(ctx, "type:gust:unit");
    result.payload_layout_id = std.Clone(ctx, "enum_payload_layout:none");
    result.payload_element_type_id = std.Clone(ctx, "type:gust:unit");
    result.payload_element_count = 0;
    result.payload_element_stride = 0;
    result.payload_size = 0;
    result.payload_alignment = 1;
    result.variant_id = mir_enum_variant_identity(enum_type_id, variant_name, declaration_index, discriminant, ctx);
    return result;
}

func mir_enum_make_payload_variant(enum_type_id: str, variant_name: str, declaration_index: int, discriminant: int, payload_type_id: str, payload_layout_id: str, payload_element_type_id: str, payload_element_count: int, payload_element_size: int, payload_element_alignment: int, ctx: &Arena) MirEnumVariant[ctx] {
    mut result: MirEnumVariant[ctx];
    result.variant_name = std.Clone(ctx, variant_name);
    result.enum_type_id = std.Clone(ctx, enum_type_id);
    result.declaration_index = declaration_index;
    result.discriminant = discriminant;
    result.has_payload = 1;
    result.payload_type_id = std.Clone(ctx, payload_type_id);
    result.payload_layout_id = std.Clone(ctx, payload_layout_id);
    result.payload_element_type_id = std.Clone(ctx, payload_element_type_id);
    result.payload_element_count = payload_element_count;
    result.payload_element_stride = mir_enum_align_up(payload_element_size, payload_element_alignment);
    result.payload_size = payload_element_count * result.payload_element_stride;
    result.payload_alignment = payload_element_alignment;
    result.variant_id = mir_enum_variant_identity(enum_type_id, variant_name, declaration_index, discriminant, ctx);
    return result;
}

// Canonical constructor for compiler-selected enum layouts. Callers supply
// variants in declaration order; this function owns tag width, tag offset, the
// shared payload offset, the maximum payload size and alignment, and the total
// size and alignment.
func mir_enum_layout_declared_variants(target_id: str, target_triple: str, enum_type_id: str, discriminant_assignment: str, tag_type_id: str, tag_layout_id: str, tag_width: int, tag_alignment: int, declared_variants: Index[std.Vector[MirEnumVariant[ctx], ctx], ctx], ctx: &Arena) MirEnumLayout[ctx] {
    mut result: MirEnumLayout[ctx];
    result.enum_type_id = std.Clone(ctx, enum_type_id);
    result.target_id = std.Clone(ctx, target_id);
    result.target_triple = std.Clone(ctx, target_triple);
    result.tag_type_id = std.Clone(ctx, tag_type_id);
    result.tag_layout_id = std.Clone(ctx, tag_layout_id);
    result.tag_width = tag_width;
    result.tag_alignment = tag_alignment;
    result.tag_offset = 0;
    result.discriminant_assignment = std.Clone(ctx, discriminant_assignment);
    result.representation_kind = std.Clone(ctx, "explicit_tag_and_payload");
    result.variants = declared_variants;

    mut variants: std.Vector[MirEnumVariant[ctx], ctx] := ctx[declared_variants];
    result.variant_count = len(variants);
    mut max_payload_size := 0;
    mut max_payload_alignment := 1;
    mut index := 0;
    while index < len(variants) {
        mut variant := variants[index];
        if variant.payload_size > max_payload_size { max_payload_size = variant.payload_size; }
        if variant.payload_alignment > max_payload_alignment { max_payload_alignment = variant.payload_alignment; }
        index = index + 1;
    }
    result.max_payload_size = max_payload_size;
    result.max_payload_alignment = max_payload_alignment;
    result.payload_offset = mir_enum_align_up(tag_width, max_payload_alignment);
    mut alignment := tag_alignment;
    if max_payload_alignment > alignment { alignment = max_payload_alignment; }
    result.alignment = alignment;
    result.size = mir_enum_align_up(result.payload_offset + max_payload_size, alignment);
    result.layout_id = mir_enum_layout_identity(
        result.target_id,
        result.enum_type_id,
        result.tag_type_id,
        result.tag_width,
        result.payload_offset,
        result.size,
        result.alignment,
        result.variant_count,
        ctx
    );
    return result;
}

func mir_enum_make_value(value_id: str, enum_layout: MirEnumLayout[ctx], variant: MirEnumVariant[ctx], payload_values: Index[std.Vector[int, ctx], ctx], storage_region: str, flow_origin: str, ctx: &Arena) MirEnumValue[ctx] {
    mut result: MirEnumValue[ctx];
    result.value_id = std.Clone(ctx, value_id);
    result.enum_layout_id = std.Clone(ctx, enum_layout.layout_id);
    result.enum_type_id = std.Clone(ctx, enum_layout.enum_type_id);
    result.variant_name = std.Clone(ctx, variant.variant_name);
    result.discriminant = variant.discriminant;
    result.payload_values = payload_values;
    result.storage_region = std.Clone(ctx, storage_region);
    result.flow_origin = std.Clone(ctx, flow_origin);
    return result;
}

func mir_enum_make_operation(table: MirEnumTable[ctx], operation_name: str, kind: str, value_id: str, variant_name: str, payload_index: int, expected_value: int, expected_offset: int, expected_tag: int, expected_arm_index: int, ctx: &Arena) MirEnumOperation[ctx] {
    mut result: MirEnumOperation[ctx];
    result.operation_name = std.Clone(ctx, operation_name);
    result.target_id = std.Clone(ctx, table.target_id);
    result.kind = std.Clone(ctx, kind);
    result.value_id = std.Clone(ctx, value_id);
    result.variant_name = std.Clone(ctx, variant_name);
    result.payload_index = payload_index;
    result.expect_success = 1;
    result.expected_value = expected_value;
    result.expected_offset = expected_offset;
    result.expected_tag = expected_tag;
    result.expected_arm_index = expected_arm_index;
    result.expected_reason_code = std.Clone(ctx, "enum_valid");
    result.operation_id = mir_enum_operation_identity(
        result.target_id,
        result.operation_name,
        result.kind,
        ctx
    );
    return result;
}

func mir_enum_table_with_layout(table: MirEnumTable[ctx], value: MirEnumLayout[ctx], ctx: &Arena) MirEnumTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirEnumLayout[ctx], ctx] := ctx[updated.layouts];
    values.Push(value);
    ctx.Set(updated.layouts, values);
    return updated;
}

func mir_enum_table_with_value(table: MirEnumTable[ctx], value: MirEnumValue[ctx], ctx: &Arena) MirEnumTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirEnumValue[ctx], ctx] := ctx[updated.values];
    values.Push(value);
    ctx.Set(updated.values, values);
    return updated;
}

func mir_enum_table_with_operation(table: MirEnumTable[ctx], value: MirEnumOperation[ctx], ctx: &Arena) MirEnumTable[ctx] {
    mut updated := table;
    mut values: std.Vector[MirEnumOperation[ctx], ctx] := ctx[updated.operations];
    values.Push(value);
    ctx.Set(updated.operations, values);
    return updated;
}

func mir_enum_layout_of(table: MirEnumTable[ctx], layout_id: str, ctx: &Arena) MirEnumLayoutQuery[ctx] {
    mut result: MirEnumLayoutQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirEnumLayout[ctx], ctx] := ctx[table.layouts];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].layout_id, layout_id) == 1 {
            result.found = 1;
            result.enum_layout = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_enum_variant_of(enum_layout: MirEnumLayout[ctx], variant_name: str, ctx: &Arena) MirEnumVariantQuery[ctx] {
    mut result: MirEnumVariantQuery[ctx];
    result.found = 0;
    mut variants: std.Vector[MirEnumVariant[ctx], ctx] := ctx[enum_layout.variants];
    mut index := 0;
    while index < len(variants) {
        if std.str_eq(variants[index].variant_name, variant_name) == 1 {
            result.found = 1;
            result.variant = variants[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_enum_value_of(table: MirEnumTable[ctx], value_id: str, ctx: &Arena) MirEnumValueQuery[ctx] {
    mut result: MirEnumValueQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirEnumValue[ctx], ctx] := ctx[table.values];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].value_id, value_id) == 1 {
            result.found = 1;
            result.enum_value = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_enum_operation_of(table: MirEnumTable[ctx], operation_name: str, ctx: &Arena) MirEnumOperationQuery[ctx] {
    mut result: MirEnumOperationQuery[ctx];
    result.found = 0;
    mut values: std.Vector[MirEnumOperation[ctx], ctx] := ctx[table.operations];
    mut index := 0;
    while index < len(values) {
        if std.str_eq(values[index].operation_name, operation_name) == 1 {
            result.found = 1;
            result.operation = values[index];
            return result;
        }
        index = index + 1;
    }
    return result;
}

func mir_enum_evaluation(success: int, value: int, offset: int, tag: int, arm_index: int, reason_code: str, ctx: &Arena) MirEnumEvaluation[ctx] {
    mut result: MirEnumEvaluation[ctx];
    result.success = success;
    result.value = value;
    result.offset = offset;
    result.tag = tag;
    result.arm_index = arm_index;
    result.reason_code = std.Clone(ctx, reason_code);
    return result;
}

func mir_enum_rejection(kind: str, ctx: &Arena) MirEnumEvaluation[ctx] {
    if std.str_eq(kind, "duplicate_discriminant") == 1 {
        return mir_enum_evaluation(0, 0, 0, 0, 0, "enum_duplicate_discriminant", ctx);
    }
    if std.str_eq(kind, "discriminant_out_of_range") == 1 {
        return mir_enum_evaluation(0, 0, 0, 0, 0, "enum_discriminant_out_of_range", ctx);
    }
    if std.str_eq(kind, "invalid_tag_value") == 1 {
        return mir_enum_evaluation(0, 0, 0, 0, 0, "enum_invalid_tag_value", ctx);
    }
    if std.str_eq(kind, "wrong_payload_type") == 1 {
        return mir_enum_evaluation(0, 0, 0, 0, 0, "enum_payload_type_mismatch", ctx);
    }
    if std.str_eq(kind, "invalid_payload_projection") == 1 {
        return mir_enum_evaluation(0, 0, 0, 0, 0, "enum_invalid_payload_projection", ctx);
    }
    if std.str_eq(kind, "inconsistent_variant_layout") == 1 {
        return mir_enum_evaluation(0, 0, 0, 0, 0, "enum_inconsistent_variant_layout", ctx);
    }
    return mir_enum_evaluation(0, 0, 0, 0, 0, "enum_request_invalid", ctx);
}

func mir_enum_evaluate(table: MirEnumTable[ctx], operation: MirEnumOperation[ctx], ctx: &Arena) MirEnumEvaluation[ctx] {
    mut value_query := mir_enum_value_of(table, operation.value_id, ctx);
    if value_query.found == 0 { return mir_enum_rejection("invalid_tag_value", ctx); }
    mut enum_value := value_query.enum_value;
    mut layout_query := mir_enum_layout_of(table, enum_value.enum_layout_id, ctx);
    if layout_query.found == 0 { return mir_enum_rejection("inconsistent_variant_layout", ctx); }
    mut enum_layout := layout_query.enum_layout;
    mut active_query := mir_enum_variant_of(enum_layout, enum_value.variant_name, ctx);
    if active_query.found == 0 { return mir_enum_rejection("invalid_tag_value", ctx); }
    mut active := active_query.variant;
    if active.discriminant != enum_value.discriminant {
        return mir_enum_rejection("invalid_tag_value", ctx);
    }

    if std.str_eq(operation.kind, "variant_construct") == 1 {
        if len(operation.variant_name) != 0 &&
           std.str_eq(operation.variant_name, enum_value.variant_name) == 0
        {
            return mir_enum_rejection("wrong_payload_type", ctx);
        }
        return mir_enum_evaluation(
            1,
            active.discriminant,
            enum_layout.tag_offset,
            active.discriminant,
            active.declaration_index,
            "enum_valid",
            ctx
        );
    }

    if std.str_eq(operation.kind, "tag_read") == 1 {
        return mir_enum_evaluation(
            1,
            active.discriminant,
            enum_layout.tag_offset,
            active.discriminant,
            active.declaration_index,
            "enum_valid",
            ctx
        );
    }

    if std.str_eq(operation.kind, "variant_test") == 1 {
        mut tested := mir_enum_variant_of(enum_layout, operation.variant_name, ctx);
        if tested.found == 0 { return mir_enum_rejection("invalid_tag_value", ctx); }
        mut matches := 0;
        if std.str_eq(tested.variant.variant_name, active.variant_name) == 1 { matches = 1; }
        return mir_enum_evaluation(
            1,
            matches,
            enum_layout.tag_offset,
            active.discriminant,
            active.declaration_index,
            "enum_valid",
            ctx
        );
    }

    if std.str_eq(operation.kind, "match_branch") == 1 {
        return mir_enum_evaluation(
            1,
            active.declaration_index,
            enum_layout.tag_offset,
            active.discriminant,
            active.declaration_index,
            "enum_valid",
            ctx
        );
    }

    if std.str_eq(operation.kind, "payload_project") == 1 {
        // A projection is only legal against the variant the tag actually
        // selects, and only inside that variant's compiler-owned payload.
        if len(operation.variant_name) != 0 &&
           std.str_eq(operation.variant_name, active.variant_name) == 0
        {
            return mir_enum_rejection("invalid_payload_projection", ctx);
        }
        if active.has_payload == 0 {
            return mir_enum_rejection("invalid_payload_projection", ctx);
        }
        if operation.payload_index < 0 || operation.payload_index >= active.payload_element_count {
            return mir_enum_rejection("invalid_payload_projection", ctx);
        }
        mut payload_values: std.Vector[int, ctx] := ctx[enum_value.payload_values];
        if len(payload_values) != active.payload_element_count {
            return mir_enum_rejection("wrong_payload_type", ctx);
        }
        mut offset := enum_layout.payload_offset + operation.payload_index * active.payload_element_stride;
        if offset + active.payload_element_stride > enum_layout.size {
            return mir_enum_rejection("invalid_payload_projection", ctx);
        }
        return mir_enum_evaluation(
            1,
            payload_values[operation.payload_index],
            offset,
            active.discriminant,
            active.declaration_index,
            "enum_valid",
            ctx
        );
    }

    return mir_enum_evaluation(0, 0, 0, 0, 0, "enum_operation_unsupported", ctx);
}

func mir_enum_layout_is_valid(table: MirEnumTable[ctx], layout_table: layout.MirLayoutTable[ctx], value: MirEnumLayout[ctx], ctx: &Arena) int {
    if std.str_eq(value.target_id, table.target_id) == 0 ||
       std.str_eq(value.target_triple, table.target_triple) == 0 ||
       std.str_eq(value.representation_kind, "explicit_tag_and_payload") == 0 ||
       mir_enum_field_is_safe(value.enum_type_id, 0) == 0 ||
       value.tag_offset != 0 ||
       value.variant_count <= 0 ||
       value.size <= 0 || value.alignment <= 0
    {
        return 0;
    }
    if std.str_eq(value.discriminant_assignment, "explicit") == 0 &&
       std.str_eq(value.discriminant_assignment, "compiler_assigned") == 0
    {
        return 0;
    }

    // The tag must be a declared scalar owned by the layout authority.
    mut tag_layout := layout.mir_layout_of(layout_table, value.tag_type_id, layout_table.target.target_id, ctx);
    if tag_layout.found == 0 ||
       std.str_eq(tag_layout.layout.layout_id, value.tag_layout_id) == 0 ||
       value.tag_width != tag_layout.layout.size ||
       value.tag_alignment != tag_layout.layout.alignment
    {
        return 0;
    }

    mut variants: std.Vector[MirEnumVariant[ctx], ctx] := ctx[value.variants];
    if len(variants) != value.variant_count { return 0; }

    mut max_discriminant := 0;
    mut max_payload_size := 0;
    mut max_payload_alignment := 1;
    mut index := 0;
    while index < len(variants) {
        mut variant := variants[index];
        if variant.declaration_index != index ||
           std.str_eq(variant.enum_type_id, value.enum_type_id) == 0 ||
           mir_enum_field_is_safe(variant.variant_name, 0) == 0 ||
           mir_enum_field_is_safe(variant.payload_type_id, 0) == 0 ||
           mir_enum_field_is_safe(variant.payload_layout_id, 0) == 0 ||
           variant.discriminant < 0 ||
           variant.payload_alignment <= 0
        {
            return 0;
        }
        mut expected_variant_id := mir_enum_variant_identity(
            variant.enum_type_id,
            variant.variant_name,
            variant.declaration_index,
            variant.discriminant,
            ctx
        );
        if std.str_eq(variant.variant_id, expected_variant_id) == 0 { return 0; }

        // Out-of-range discriminants are rejected against the selected tag.
        if variant.discriminant > mir_enum_tag_capacity(value.tag_type_id) { return 0; }

        // Duplicate discriminants and duplicate variant names are rejected.
        mut duplicate := index + 1;
        while duplicate < len(variants) {
            if variants[index].discriminant == variants[duplicate].discriminant { return 0; }
            if std.str_eq(variants[index].variant_name, variants[duplicate].variant_name) == 1 { return 0; }
            duplicate = duplicate + 1;
        }

        // Inconsistent variant layout is rejected before any consumer sees it.
        if variant.has_payload == 0 {
            if variant.payload_element_count != 0 || variant.payload_element_stride != 0 ||
               variant.payload_size != 0 || variant.payload_alignment != 1
            {
                return 0;
            }
        } else {
            if variant.payload_element_count <= 0 || variant.payload_element_stride <= 0 ||
               variant.payload_size != variant.payload_element_count * variant.payload_element_stride ||
               mir_enum_align_up(variant.payload_element_stride, variant.payload_alignment) != variant.payload_element_stride
            {
                return 0;
            }
        }
        if variant.discriminant > max_discriminant { max_discriminant = variant.discriminant; }
        if variant.payload_size > max_payload_size { max_payload_size = variant.payload_size; }
        if variant.payload_alignment > max_payload_alignment { max_payload_alignment = variant.payload_alignment; }
        index = index + 1;
    }

    // Tag selection, payload placement, and total size are compiler-owned and
    // must match exactly what this authority would have chosen.
    if std.str_eq(value.tag_type_id, mir_enum_select_tag_type_id(max_discriminant)) == 0 { return 0; }
    if value.max_payload_size != max_payload_size ||
       value.max_payload_alignment != max_payload_alignment ||
       value.payload_offset != mir_enum_align_up(value.tag_width, max_payload_alignment)
    {
        return 0;
    }
    mut expected_alignment := value.tag_alignment;
    if max_payload_alignment > expected_alignment { expected_alignment = max_payload_alignment; }
    if value.alignment != expected_alignment { return 0; }
    if value.size != mir_enum_align_up(value.payload_offset + max_payload_size, expected_alignment) { return 0; }
    if value.payload_offset < value.tag_width { return 0; }

    mut expected_layout_id := mir_enum_layout_identity(
        value.target_id,
        value.enum_type_id,
        value.tag_type_id,
        value.tag_width,
        value.payload_offset,
        value.size,
        value.alignment,
        value.variant_count,
        ctx
    );
    if std.str_eq(value.layout_id, expected_layout_id) == 0 { return 0; }
    return 1;
}

func mir_enum_table_is_valid(table: MirEnumTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) int {
    if std.str_eq(table.format, "gust.compiler_enum_table.v1") == 0 { return 0; }
    if mir_enum_table_is_legacy_empty(table, ctx) == 1 { return 1; }
    if std.str_eq(table.target_id, layout_table.target.target_id) == 0 ||
       std.str_eq(table.target_triple, layout_table.target.target_triple) == 0 ||
       std.str_eq(table.tag_authority, "compiler_owned_tag_selection_no_backend_inference") == 0 ||
       std.str_eq(table.discriminant_policy, "explicit_or_compiler_assigned_unique_discriminants") == 0 ||
       std.str_eq(table.payload_policy, "explicit_tag_with_shared_payload_offset") == 0 ||
       std.str_eq(table.niche_policy, "deferred_niche_optimization") == 0 ||
       std.str_eq(table.match_policy, "checked_tag_dispatch_over_declared_variants") == 0 ||
       std.str_eq(table.struct_payload_policy, "deferred_struct_payloads_not_selected_by_patch14_10") == 0
    {
        return 0;
    }

    mut layouts: std.Vector[MirEnumLayout[ctx], ctx] := ctx[table.layouts];
    mut values: std.Vector[MirEnumValue[ctx], ctx] := ctx[table.values];
    mut operations: std.Vector[MirEnumOperation[ctx], ctx] := ctx[table.operations];
    if len(layouts) != 5 || len(values) != 11 || len(operations) != 20 { return 0; }

    mut layout_index := 0;
    while layout_index < len(layouts) {
        if mir_enum_layout_is_valid(table, layout_table, layouts[layout_index], ctx) == 0 { return 0; }
        mut duplicate := layout_index + 1;
        while duplicate < len(layouts) {
            if std.str_eq(layouts[layout_index].layout_id, layouts[duplicate].layout_id) == 1 { return 0; }
            if std.str_eq(layouts[layout_index].enum_type_id, layouts[duplicate].enum_type_id) == 1 { return 0; }
            duplicate = duplicate + 1;
        }
        layout_index = layout_index + 1;
    }

    mut value_index := 0;
    while value_index < len(values) {
        mut value := values[value_index];
        mut layout_query := mir_enum_layout_of(table, value.enum_layout_id, ctx);
        if layout_query.found == 0 { return 0; }
        mut variant_query := mir_enum_variant_of(layout_query.enum_layout, value.variant_name, ctx);
        mut payload_values: std.Vector[int, ctx] := ctx[value.payload_values];
        if variant_query.found == 0 ||
           variant_query.variant.discriminant != value.discriminant ||
           len(payload_values) != variant_query.variant.payload_element_count ||
           std.str_eq(value.enum_type_id, layout_query.enum_layout.enum_type_id) == 0 ||
           std.str_eq(value.storage_region, "function:main") == 0 ||
           mir_enum_field_is_safe(value.value_id, 0) == 0 ||
           mir_enum_field_is_safe(value.flow_origin, 0) == 0
        {
            return 0;
        }
        mut duplicate_value := value_index + 1;
        while duplicate_value < len(values) {
            if std.str_eq(values[value_index].value_id, values[duplicate_value].value_id) == 1 { return 0; }
            duplicate_value = duplicate_value + 1;
        }
        value_index = value_index + 1;
    }

    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        if mir_enum_operation_kind_is_valid(operation.kind) == 0 ||
           std.str_eq(operation.target_id, table.target_id) == 0 ||
           operation.expect_success != 1 ||
           std.str_eq(operation.expected_reason_code, "enum_valid") == 0 ||
           mir_enum_field_is_safe(operation.operation_name, 0) == 0
        {
            return 0;
        }
        mut expected_id := mir_enum_operation_identity(
            operation.target_id,
            operation.operation_name,
            operation.kind,
            ctx
        );
        if std.str_eq(operation.operation_id, expected_id) == 0 { return 0; }
        mut duplicate_operation := operation_index + 1;
        while duplicate_operation < len(operations) {
            if std.str_eq(operations[operation_index].operation_id, operations[duplicate_operation].operation_id) == 1 { return 0; }
            duplicate_operation = duplicate_operation + 1;
        }
        mut evaluation := mir_enum_evaluate(table, operation, ctx);
        if evaluation.success != operation.expect_success ||
           evaluation.value != operation.expected_value ||
           evaluation.offset != operation.expected_offset ||
           evaluation.tag != operation.expected_tag ||
           evaluation.arm_index != operation.expected_arm_index ||
           std.str_eq(evaluation.reason_code, operation.expected_reason_code) == 0
        {
            return 0;
        }
        operation_index = operation_index + 1;
    }
    return 1;
}

func mir_enum_payload0(ctx: &Arena) Index[std.Vector[int, ctx], ctx] {
    return mir_enum_empty_int_vector(ctx);
}

func mir_enum_payload1(a: int, ctx: &Arena) Index[std.Vector[int, ctx], ctx] {
    mut values := mir_enum_empty_int_vector(ctx);
    mut vector: std.Vector[int, ctx] := ctx[values];
    vector.Push(a);
    ctx.Set(values, vector);
    return values;
}

func mir_enum_payload2(a: int, b: int, ctx: &Arena) Index[std.Vector[int, ctx], ctx] {
    mut values := mir_enum_empty_int_vector(ctx);
    mut vector: std.Vector[int, ctx] := ctx[values];
    vector.Push(a); vector.Push(b);
    ctx.Set(values, vector);
    return values;
}

func mir_enum_variants_of(ctx: &Arena) Index[std.Vector[MirEnumVariant[ctx], ctx], ctx] {
    return mir_enum_empty_variant_vector(ctx);
}

func mir_enum_push_variant(target: Index[std.Vector[MirEnumVariant[ctx], ctx], ctx], value: MirEnumVariant[ctx], ctx: &Arena) Index[std.Vector[MirEnumVariant[ctx], ctx], ctx] {
    mut vector: std.Vector[MirEnumVariant[ctx], ctx] := ctx[target];
    vector.Push(value);
    ctx.Set(target, vector);
    return target;
}

func mir_enum_table_for_layout(layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) MirEnumTable[ctx] {
    mut table := mir_enum_make_empty_table(layout_table.target.target_triple, ctx);
    table.target_id = std.Clone(ctx, layout_table.target.target_id);

    mut i32_layout := layout.mir_layout_of(layout_table, "type:gust:i32", layout_table.target.target_id, ctx);
    mut u8_layout := layout.mir_layout_of(layout_table, "type:gust:u8", layout_table.target.target_id, ctx);

    // The selected aggregate payload reuses the stable Patch 14.8 fixed-array
    // authority rather than inventing a second array layout rule.
    mut pair_layout := array_slice.mir_array_slice_make_array_layout(
        table.target_id, table.target_triple, "type:gust:array:i32:2",
        "type:gust:i32", i32_layout.layout.layout_id,
        i32_layout.layout.size, i32_layout.layout.alignment, 2, 1, ctx
    );

    // 1. Fieldless enum with compiler-assigned discriminants.
    mut color_variants := mir_enum_variants_of(ctx);
    color_variants = mir_enum_push_variant(color_variants, mir_enum_make_fieldless_variant("type:gust:enum:Color", "Red", 0, 0, ctx), ctx);
    color_variants = mir_enum_push_variant(color_variants, mir_enum_make_fieldless_variant("type:gust:enum:Color", "Green", 1, 1, ctx), ctx);
    color_variants = mir_enum_push_variant(color_variants, mir_enum_make_fieldless_variant("type:gust:enum:Color", "Blue", 2, 2, ctx), ctx);
    mut color := mir_enum_layout_declared_variants(
        table.target_id, table.target_triple, "type:gust:enum:Color", "compiler_assigned",
        "type:gust:u8", u8_layout.layout.layout_id, u8_layout.layout.size, u8_layout.layout.alignment,
        color_variants, ctx
    );

    // 2. Fieldless enum with explicit discriminants that force a wider tag.
    mut status_variants := mir_enum_variants_of(ctx);
    status_variants = mir_enum_push_variant(status_variants, mir_enum_make_fieldless_variant("type:gust:enum:Status", "Ok", 0, 100, ctx), ctx);
    status_variants = mir_enum_push_variant(status_variants, mir_enum_make_fieldless_variant("type:gust:enum:Status", "Retry", 1, 200, ctx), ctx);
    status_variants = mir_enum_push_variant(status_variants, mir_enum_make_fieldless_variant("type:gust:enum:Status", "Fatal", 2, 300, ctx), ctx);
    mut status := mir_enum_layout_declared_variants(
        table.target_id, table.target_triple, "type:gust:enum:Status", "explicit",
        "type:gust:i32", i32_layout.layout.layout_id, i32_layout.layout.size, i32_layout.layout.alignment,
        status_variants, ctx
    );

    // 3. Single-payload variant alongside a fieldless variant.
    mut maybe_variants := mir_enum_variants_of(ctx);
    maybe_variants = mir_enum_push_variant(maybe_variants, mir_enum_make_fieldless_variant("type:gust:enum:MaybeI32", "None", 0, 0, ctx), ctx);
    maybe_variants = mir_enum_push_variant(maybe_variants, mir_enum_make_payload_variant(
        "type:gust:enum:MaybeI32", "Some", 1, 1,
        "type:gust:i32", i32_layout.layout.layout_id, "type:gust:i32",
        1, i32_layout.layout.size, i32_layout.layout.alignment, ctx
    ), ctx);
    mut maybe := mir_enum_layout_declared_variants(
        table.target_id, table.target_triple, "type:gust:enum:MaybeI32", "compiler_assigned",
        "type:gust:u8", u8_layout.layout.layout_id, u8_layout.layout.size, u8_layout.layout.alignment,
        maybe_variants, ctx
    );

    // 4. Multiple variants with different payload layouts.
    mut packet_variants := mir_enum_variants_of(ctx);
    packet_variants = mir_enum_push_variant(packet_variants, mir_enum_make_fieldless_variant("type:gust:enum:Packet", "Empty", 0, 0, ctx), ctx);
    packet_variants = mir_enum_push_variant(packet_variants, mir_enum_make_payload_variant(
        "type:gust:enum:Packet", "Small", 1, 1,
        "type:gust:u8", u8_layout.layout.layout_id, "type:gust:u8",
        1, u8_layout.layout.size, u8_layout.layout.alignment, ctx
    ), ctx);
    packet_variants = mir_enum_push_variant(packet_variants, mir_enum_make_payload_variant(
        "type:gust:enum:Packet", "Large", 2, 2,
        "type:gust:i32", i32_layout.layout.layout_id, "type:gust:i32",
        1, i32_layout.layout.size, i32_layout.layout.alignment, ctx
    ), ctx);
    mut packet := mir_enum_layout_declared_variants(
        table.target_id, table.target_triple, "type:gust:enum:Packet", "compiler_assigned",
        "type:gust:u8", u8_layout.layout.layout_id, u8_layout.layout.size, u8_layout.layout.alignment,
        packet_variants, ctx
    );

    // 5. Nested aggregate payload carried by the Patch 14.8 array authority.
    mut batch_variants := mir_enum_variants_of(ctx);
    batch_variants = mir_enum_push_variant(batch_variants, mir_enum_make_fieldless_variant("type:gust:enum:Batch", "Idle", 0, 0, ctx), ctx);
    batch_variants = mir_enum_push_variant(batch_variants, mir_enum_make_payload_variant(
        "type:gust:enum:Batch", "Pair", 1, 1,
        pair_layout.array_type_id, pair_layout.layout_id, pair_layout.element_type_id,
        pair_layout.element_count, i32_layout.layout.size, i32_layout.layout.alignment, ctx
    ), ctx);
    mut batch := mir_enum_layout_declared_variants(
        table.target_id, table.target_triple, "type:gust:enum:Batch", "compiler_assigned",
        "type:gust:u8", u8_layout.layout.layout_id, u8_layout.layout.size, u8_layout.layout.alignment,
        batch_variants, ctx
    );

    table = mir_enum_table_with_layout(table, color, ctx);
    table = mir_enum_table_with_layout(table, status, ctx);
    table = mir_enum_table_with_layout(table, maybe, ctx);
    table = mir_enum_table_with_layout(table, packet, ctx);
    table = mir_enum_table_with_layout(table, batch, ctx);

    mut color_green := mir_enum_variant_of(color, "Green", ctx);
    mut color_blue := mir_enum_variant_of(color, "Blue", ctx);
    mut status_retry := mir_enum_variant_of(status, "Retry", ctx);
    mut maybe_none := mir_enum_variant_of(maybe, "None", ctx);
    mut maybe_some := mir_enum_variant_of(maybe, "Some", ctx);
    mut packet_small := mir_enum_variant_of(packet, "Small", ctx);
    mut packet_large := mir_enum_variant_of(packet, "Large", ctx);
    mut batch_idle := mir_enum_variant_of(batch, "Idle", ctx);
    mut batch_pair := mir_enum_variant_of(batch, "Pair", ctx);

    table = mir_enum_table_with_value(table, mir_enum_make_value("enum_color_green", color, color_green.variant, mir_enum_payload0(ctx), "function:main", "direct", ctx), ctx);
    table = mir_enum_table_with_value(table, mir_enum_make_value("enum_color_blue", color, color_blue.variant, mir_enum_payload0(ctx), "function:main", "direct", ctx), ctx);
    table = mir_enum_table_with_value(table, mir_enum_make_value("enum_status_retry", status, status_retry.variant, mir_enum_payload0(ctx), "function:main", "direct", ctx), ctx);
    table = mir_enum_table_with_value(table, mir_enum_make_value("enum_maybe_some", maybe, maybe_some.variant, mir_enum_payload1(77, ctx), "function:main", "direct", ctx), ctx);
    table = mir_enum_table_with_value(table, mir_enum_make_value("enum_maybe_none", maybe, maybe_none.variant, mir_enum_payload0(ctx), "function:main", "direct", ctx), ctx);
    table = mir_enum_table_with_value(table, mir_enum_make_value("enum_packet_small", packet, packet_small.variant, mir_enum_payload1(200, ctx), "function:main", "direct", ctx), ctx);
    table = mir_enum_table_with_value(table, mir_enum_make_value("enum_packet_large", packet, packet_large.variant, mir_enum_payload1(123456, ctx), "function:main", "direct", ctx), ctx);
    table = mir_enum_table_with_value(table, mir_enum_make_value("enum_batch_pair", batch, batch_pair.variant, mir_enum_payload2(5, 9, ctx), "function:main", "direct", ctx), ctx);
    table = mir_enum_table_with_value(table, mir_enum_make_value("enum_batch_idle", batch, batch_idle.variant, mir_enum_payload0(ctx), "function:main", "direct", ctx), ctx);
    // Enum value held in an addressable local.
    table = mir_enum_table_with_value(table, mir_enum_make_value("enum_local_maybe", maybe, maybe_some.variant, mir_enum_payload1(64, ctx), "function:main", "local:slot0", ctx), ctx);
    // Enum value observed after a branch join.
    table = mir_enum_table_with_value(table, mir_enum_make_value("enum_branch_maybe", maybe, maybe_some.variant, mir_enum_payload1(91, ctx), "function:main", "branch_join:block1:block2:block3", ctx), ctx);

    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "construct_color_green", "variant_construct", "enum_color_green", "Green", 0, 1, 0, 1, 1, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "tag_read_color_green", "tag_read", "enum_color_green", "", 0, 1, 0, 1, 1, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "variant_test_color_green_true", "variant_test", "enum_color_green", "Green", 0, 1, 0, 1, 1, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "variant_test_color_green_false", "variant_test", "enum_color_green", "Red", 0, 0, 0, 1, 1, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "match_color_blue", "match_branch", "enum_color_blue", "", 0, 2, 0, 2, 2, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "tag_read_status_retry", "tag_read", "enum_status_retry", "", 0, 200, 0, 200, 1, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "match_status_retry", "match_branch", "enum_status_retry", "", 0, 1, 0, 200, 1, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "construct_maybe_some", "variant_construct", "enum_maybe_some", "Some", 0, 1, 0, 1, 1, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "tag_read_maybe_some", "tag_read", "enum_maybe_some", "", 0, 1, 0, 1, 1, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "payload_project_maybe_some", "payload_project", "enum_maybe_some", "Some", 0, 77, 4, 1, 1, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "variant_test_maybe_none", "variant_test", "enum_maybe_none", "None", 0, 1, 0, 0, 0, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "match_maybe_none", "match_branch", "enum_maybe_none", "", 0, 0, 0, 0, 0, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "payload_project_packet_small", "payload_project", "enum_packet_small", "Small", 0, 200, 4, 1, 1, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "payload_project_packet_large", "payload_project", "enum_packet_large", "Large", 0, 123456, 4, 2, 2, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "match_packet_large", "match_branch", "enum_packet_large", "", 0, 2, 0, 2, 2, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "payload_project_batch_pair_first", "payload_project", "enum_batch_pair", "Pair", 0, 5, 4, 1, 1, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "payload_project_batch_pair_second", "payload_project", "enum_batch_pair", "Pair", 1, 9, 8, 1, 1, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "tag_read_batch_idle", "tag_read", "enum_batch_idle", "", 0, 0, 0, 0, 0, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "payload_project_local_maybe", "payload_project", "enum_local_maybe", "Some", 0, 64, 4, 1, 1, ctx), ctx);
    table = mir_enum_table_with_operation(table, mir_enum_make_operation(table, "payload_project_branch_maybe", "payload_project", "enum_branch_maybe", "Some", 0, 91, 4, 1, 1, ctx), ctx);
    return table;
}

func mir_enum_append_field(output: str, key: str, value: str, ctx: &Arena) str {
    mut updated := std.Concat(output, key);
    updated = std.Concat(updated, ": ");
    updated = std.Concat(updated, value);
    updated = std.Concat(updated, "\n");
    return std.Clone(ctx, updated);
}

func mir_serialize_enum_table_for_request(table: MirEnumTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_enum_table_is_legacy_empty(table, ctx) == 1 {
        return "enum_table_format: gust.compiler_enum_table.v1\nenum_target_id: \nenum_target_triple: legacy-empty\nenum_layout_count: 0\nenum_value_count: 0\nenum_operation_count: 0\n";
    }
    if mir_enum_table_is_valid(table, layout_table, ctx) == 0 {
        return "enum_table_format: invalid\n";
    }
    mut output := "";
    output = mir_enum_append_field(output, "enum_table_format", table.format, ctx);
    output = mir_enum_append_field(output, "enum_target_id", table.target_id, ctx);
    output = mir_enum_append_field(output, "enum_target_triple", table.target_triple, ctx);
    output = mir_enum_append_field(output, "enum_tag_authority", table.tag_authority, ctx);
    output = mir_enum_append_field(output, "enum_discriminant_policy", table.discriminant_policy, ctx);
    output = mir_enum_append_field(output, "enum_payload_policy", table.payload_policy, ctx);
    output = mir_enum_append_field(output, "enum_niche_policy", table.niche_policy, ctx);
    output = mir_enum_append_field(output, "enum_match_policy", table.match_policy, ctx);
    output = mir_enum_append_field(output, "enum_struct_payload_policy", table.struct_payload_policy, ctx);

    mut layouts: std.Vector[MirEnumLayout[ctx], ctx] := ctx[table.layouts];
    output = mir_enum_append_field(output, "enum_layout_count", std.FormatInt(len(layouts)), ctx);
    mut layout_index := 0;
    while layout_index < len(layouts) {
        mut prefix := std.Concat("enum_layout_", std.FormatInt(layout_index));
        mut value := layouts[layout_index];
        output = mir_enum_append_field(output, std.Concat(prefix, "_id"), value.layout_id, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_type_id"), value.enum_type_id, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_target_id"), value.target_id, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_tag_type_id"), value.tag_type_id, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_tag_layout_id"), value.tag_layout_id, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_tag_width"), std.FormatInt(value.tag_width), ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_tag_alignment"), std.FormatInt(value.tag_alignment), ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_tag_offset"), std.FormatInt(value.tag_offset), ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_discriminant_assignment"), value.discriminant_assignment, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_payload_offset"), std.FormatInt(value.payload_offset), ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_max_payload_size"), std.FormatInt(value.max_payload_size), ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_max_payload_alignment"), std.FormatInt(value.max_payload_alignment), ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_size"), std.FormatInt(value.size), ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_alignment"), std.FormatInt(value.alignment), ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_representation_kind"), value.representation_kind, ctx);
        mut variants: std.Vector[MirEnumVariant[ctx], ctx] := ctx[value.variants];
        output = mir_enum_append_field(output, std.Concat(prefix, "_variant_count"), std.FormatInt(len(variants)), ctx);
        mut variant_index := 0;
        while variant_index < len(variants) {
            mut variant_prefix := std.Concat(prefix, std.Concat("_variant_", std.FormatInt(variant_index)));
            mut variant := variants[variant_index];
            output = mir_enum_append_field(output, std.Concat(variant_prefix, "_id"), variant.variant_id, ctx);
            output = mir_enum_append_field(output, std.Concat(variant_prefix, "_name"), variant.variant_name, ctx);
            output = mir_enum_append_field(output, std.Concat(variant_prefix, "_declaration_index"), std.FormatInt(variant.declaration_index), ctx);
            output = mir_enum_append_field(output, std.Concat(variant_prefix, "_discriminant"), std.FormatInt(variant.discriminant), ctx);
            output = mir_enum_append_field(output, std.Concat(variant_prefix, "_has_payload"), std.FormatInt(variant.has_payload), ctx);
            output = mir_enum_append_field(output, std.Concat(variant_prefix, "_payload_type_id"), variant.payload_type_id, ctx);
            output = mir_enum_append_field(output, std.Concat(variant_prefix, "_payload_layout_id"), variant.payload_layout_id, ctx);
            output = mir_enum_append_field(output, std.Concat(variant_prefix, "_payload_element_type_id"), variant.payload_element_type_id, ctx);
            output = mir_enum_append_field(output, std.Concat(variant_prefix, "_payload_element_count"), std.FormatInt(variant.payload_element_count), ctx);
            output = mir_enum_append_field(output, std.Concat(variant_prefix, "_payload_element_stride"), std.FormatInt(variant.payload_element_stride), ctx);
            output = mir_enum_append_field(output, std.Concat(variant_prefix, "_payload_size"), std.FormatInt(variant.payload_size), ctx);
            output = mir_enum_append_field(output, std.Concat(variant_prefix, "_payload_alignment"), std.FormatInt(variant.payload_alignment), ctx);
            variant_index = variant_index + 1;
        }
        layout_index = layout_index + 1;
    }

    mut values: std.Vector[MirEnumValue[ctx], ctx] := ctx[table.values];
    output = mir_enum_append_field(output, "enum_value_count", std.FormatInt(len(values)), ctx);
    mut value_index := 0;
    while value_index < len(values) {
        mut prefix := std.Concat("enum_value_", std.FormatInt(value_index));
        mut value := values[value_index];
        mut payload_values: std.Vector[int, ctx] := ctx[value.payload_values];
        output = mir_enum_append_field(output, std.Concat(prefix, "_id"), value.value_id, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_layout_id"), value.enum_layout_id, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_type_id"), value.enum_type_id, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_variant_name"), value.variant_name, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_discriminant"), std.FormatInt(value.discriminant), ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_payload_value_count"), std.FormatInt(len(payload_values)), ctx);
        mut payload_index := 0;
        while payload_index < len(payload_values) {
            mut payload_key := std.Concat(prefix, std.Concat("_payload_", std.FormatInt(payload_index)));
            output = mir_enum_append_field(output, std.Concat(payload_key, "_value"), std.FormatInt(payload_values[payload_index]), ctx);
            payload_index = payload_index + 1;
        }
        output = mir_enum_append_field(output, std.Concat(prefix, "_storage_region"), value.storage_region, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_flow_origin"), value.flow_origin, ctx);
        value_index = value_index + 1;
    }

    mut operations: std.Vector[MirEnumOperation[ctx], ctx] := ctx[table.operations];
    output = mir_enum_append_field(output, "enum_operation_count", std.FormatInt(len(operations)), ctx);
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut prefix := std.Concat("enum_operation_", std.FormatInt(operation_index));
        mut value := operations[operation_index];
        output = mir_enum_append_field(output, std.Concat(prefix, "_id"), value.operation_id, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_name"), value.operation_name, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_target_id"), value.target_id, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_kind"), value.kind, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_value_id"), value.value_id, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_variant_name"), value.variant_name, ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_payload_index"), std.FormatInt(value.payload_index), ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_expect_success"), std.FormatInt(value.expect_success), ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_expected_value"), std.FormatInt(value.expected_value), ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_expected_offset"), std.FormatInt(value.expected_offset), ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_expected_tag"), std.FormatInt(value.expected_tag), ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_expected_arm_index"), std.FormatInt(value.expected_arm_index), ctx);
        output = mir_enum_append_field(output, std.Concat(prefix, "_expected_reason_code"), value.expected_reason_code, ctx);
        operation_index = operation_index + 1;
    }
    return std.Clone(ctx, output);
}

func mir_enum_witness(table: MirEnumTable[ctx], layout_table: layout.MirLayoutTable[ctx], ctx: &Arena) str {
    if mir_enum_table_is_valid(table, layout_table, ctx) == 0 ||
       mir_enum_table_is_legacy_empty(table, ctx) == 1
    {
        return "";
    }
    mut output := "enum_status: valid\n";
    output = mir_enum_append_field(output, "enum_target", table.target_triple, ctx);
    output = mir_enum_append_field(output, "enum_target_id", table.target_id, ctx);
    output = mir_enum_append_field(output, "enum_tag_authority", table.tag_authority, ctx);
    output = mir_enum_append_field(output, "enum_discriminant_policy", table.discriminant_policy, ctx);
    output = mir_enum_append_field(output, "enum_payload_policy", table.payload_policy, ctx);
    output = mir_enum_append_field(output, "enum_niche_policy", table.niche_policy, ctx);
    output = mir_enum_append_field(output, "enum_match_policy", table.match_policy, ctx);

    mut layouts: std.Vector[MirEnumLayout[ctx], ctx] := ctx[table.layouts];
    mut layout_index := 0;
    while layout_index < len(layouts) {
        mut value := layouts[layout_index];
        mut line := "enum_layout: ";
        line = std.Concat(line, value.layout_id);
        line = std.Concat(line, " type="); line = std.Concat(line, value.enum_type_id);
        line = std.Concat(line, " tag_type="); line = std.Concat(line, value.tag_type_id);
        line = std.Concat(line, " tag_width="); line = std.Concat(line, std.FormatInt(value.tag_width));
        line = std.Concat(line, " tag_offset="); line = std.Concat(line, std.FormatInt(value.tag_offset));
        line = std.Concat(line, " assignment="); line = std.Concat(line, value.discriminant_assignment);
        line = std.Concat(line, " payload_offset="); line = std.Concat(line, std.FormatInt(value.payload_offset));
        line = std.Concat(line, " max_payload_size="); line = std.Concat(line, std.FormatInt(value.max_payload_size));
        line = std.Concat(line, " max_payload_alignment="); line = std.Concat(line, std.FormatInt(value.max_payload_alignment));
        line = std.Concat(line, " size="); line = std.Concat(line, std.FormatInt(value.size));
        line = std.Concat(line, " alignment="); line = std.Concat(line, std.FormatInt(value.alignment));
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        mut variants: std.Vector[MirEnumVariant[ctx], ctx] := ctx[value.variants];
        mut variant_index := 0;
        while variant_index < len(variants) {
            mut variant := variants[variant_index];
            mut variant_line := "enum_variant: ";
            variant_line = std.Concat(variant_line, value.enum_type_id);
            variant_line = std.Concat(variant_line, ".");
            variant_line = std.Concat(variant_line, variant.variant_name);
            variant_line = std.Concat(variant_line, " declaration_index="); variant_line = std.Concat(variant_line, std.FormatInt(variant.declaration_index));
            variant_line = std.Concat(variant_line, " discriminant="); variant_line = std.Concat(variant_line, std.FormatInt(variant.discriminant));
            variant_line = std.Concat(variant_line, " has_payload="); variant_line = std.Concat(variant_line, std.FormatInt(variant.has_payload));
            variant_line = std.Concat(variant_line, " payload_type="); variant_line = std.Concat(variant_line, variant.payload_type_id);
            variant_line = std.Concat(variant_line, " payload_size="); variant_line = std.Concat(variant_line, std.FormatInt(variant.payload_size));
            variant_line = std.Concat(variant_line, " payload_alignment="); variant_line = std.Concat(variant_line, std.FormatInt(variant.payload_alignment));
            variant_line = std.Concat(variant_line, "\n");
            output = std.Concat(output, variant_line);
            variant_index = variant_index + 1;
        }
        layout_index = layout_index + 1;
    }

    mut values: std.Vector[MirEnumValue[ctx], ctx] := ctx[table.values];
    mut value_index := 0;
    while value_index < len(values) {
        mut value := values[value_index];
        mut line := "enum_value: ";
        line = std.Concat(line, value.value_id);
        line = std.Concat(line, " type="); line = std.Concat(line, value.enum_type_id);
        line = std.Concat(line, " variant="); line = std.Concat(line, value.variant_name);
        line = std.Concat(line, " discriminant="); line = std.Concat(line, std.FormatInt(value.discriminant));
        line = std.Concat(line, " storage="); line = std.Concat(line, value.storage_region);
        line = std.Concat(line, " flow="); line = std.Concat(line, value.flow_origin);
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        value_index = value_index + 1;
    }

    mut operations: std.Vector[MirEnumOperation[ctx], ctx] := ctx[table.operations];
    mut operation_index := 0;
    while operation_index < len(operations) {
        mut operation := operations[operation_index];
        mut evaluation := mir_enum_evaluate(table, operation, ctx);
        mut line := "enum_operation: ";
        line = std.Concat(line, operation.operation_name);
        line = std.Concat(line, " kind="); line = std.Concat(line, operation.kind);
        line = std.Concat(line, " status=");
        if evaluation.success == 1 { line = std.Concat(line, "success"); }
        else { line = std.Concat(line, "failure"); }
        line = std.Concat(line, " value="); line = std.Concat(line, std.FormatInt(evaluation.value));
        line = std.Concat(line, " offset="); line = std.Concat(line, std.FormatInt(evaluation.offset));
        line = std.Concat(line, " tag="); line = std.Concat(line, std.FormatInt(evaluation.tag));
        line = std.Concat(line, " arm_index="); line = std.Concat(line, std.FormatInt(evaluation.arm_index));
        line = std.Concat(line, " reason="); line = std.Concat(line, evaluation.reason_code);
        line = std.Concat(line, "\n");
        output = std.Concat(output, line);
        operation_index = operation_index + 1;
    }
    return std.Clone(ctx, output);
}
