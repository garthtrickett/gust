// Phase 16.7 compiler-owned fat-pointer and selected trait-object call ABI.
import "mir_layout.gst" as layout;
import "mir_function_abi_authority.gst" as abi;

type MirFatPointerTraitCall[ctx] struct {
    call_id: str, fat_pointer_id: str, trait_object_id: str, form: str,
    representation: str, data_component_id: str, data_type_id: str,
    data_layout_id: str, data_placement: str, metadata_component_id: str,
    metadata_type_id: str, metadata_layout_id: str, metadata_placement: str,
    metadata_present: int, pair_id: str, actual_pair_id: str,
    vtable_id: str, actual_vtable_id: str, method_signature_id: str,
    actual_method_signature_id: str, slot_id: str, actual_slot_id: str,
    slot_ordinal: int, call_abi_id: str, actual_call_abi_id: str,
    operations: str, required_alignment: int, actual_alignment: int,
    resource_disposition: str, expected_result: int, actual_result: int,
    target_id: str, actual_target_id: str, target_triple: str,
    actual_target_triple: str, source_location: str
}

type MirFatPointerAbiTable[ctx] struct {
    format: str, target_id: str, target_triple: str, authority: str,
    representation_policy: str,
    calls: Index[std.Vector[MirFatPointerTraitCall[ctx], ctx], ctx]
}

type MirFatPointerAbiValidation[ctx] struct { valid: int, reason_code: str }

func mir_fat_pointer_empty_calls(ctx: &Arena) Index[std.Vector[MirFatPointerTraitCall[ctx], ctx], ctx] {
    mut values: std.Vector[MirFatPointerTraitCall[ctx], ctx] := std.VectorNew(ctx); mut index: Index[std.Vector[MirFatPointerTraitCall[ctx], ctx], ctx] := os.ArenaAlloc(ctx); ctx.Set(index, values); return index;
}
func mir_fat_pointer_make_empty_table(target_id: str, target_triple: str, ctx: &Arena) MirFatPointerAbiTable[ctx] {
    mut table: MirFatPointerAbiTable[ctx]; table.format = std.Clone(ctx, "gust.compiler_fat_pointer_abi.v1"); table.target_id = std.Clone(ctx, target_id); table.target_triple = std.Clone(ctx, target_triple); table.authority = std.Clone(ctx, "compiler_owned_fat_pointer_components_vtable_slot_and_call_abi"); table.representation_policy = std.Clone(ctx, "selected_two_word_data_and_vtable_no_backend_interpretation"); table.calls = mir_fat_pointer_empty_calls(ctx); return table;
}
func mir_fat_pointer_table_with_call(table: MirFatPointerAbiTable[ctx], value: MirFatPointerTraitCall[ctx], ctx: &Arena) MirFatPointerAbiTable[ctx] { mut updated := table; mut values: std.Vector[MirFatPointerTraitCall[ctx], ctx] := ctx[updated.calls]; values.Push(value); ctx.Set(updated.calls, values); return updated; }
func mir_fat_pointer_validation(valid: int, reason_code: str, ctx: &Arena) MirFatPointerAbiValidation[ctx] { mut result: MirFatPointerAbiValidation[ctx]; result.valid = valid; result.reason_code = std.Clone(ctx, reason_code); return result; }
func mir_fat_pointer_layout_by_id(table: layout.MirLayoutTable[ctx], layout_id: str, ctx: &Arena) layout.MirTypeLayoutQuery[ctx] { mut result: layout.MirTypeLayoutQuery[ctx]; result.found = 0; mut values: std.Vector[layout.MirTypeLayout[ctx], ctx] := ctx[table.layouts]; mut index := 0; while index < len(values) { if std.str_eq(values[index].layout_id, layout_id) == 1 { result.found = 1; result.layout = values[index]; return result; } index = index + 1; } return result; }

func mir_fat_pointer_abi_table_validate(table: MirFatPointerAbiTable[ctx], layouts: layout.MirLayoutTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) MirFatPointerAbiValidation[ctx] {
    if std.str_eq(table.format, "gust.compiler_fat_pointer_abi.v1") == 0 { return mir_fat_pointer_validation(0, "fat_pointer_unknown_format", ctx); }
    if std.str_eq(table.authority, "compiler_owned_fat_pointer_components_vtable_slot_and_call_abi") == 0 || std.str_eq(table.representation_policy, "selected_two_word_data_and_vtable_no_backend_interpretation") == 0 { return mir_fat_pointer_validation(0, "fat_pointer_backend_local_vtable_interpretation", ctx); }
    if layout.mir_layout_table_is_valid(layouts, ctx) == 0 { return mir_fat_pointer_validation(0, "fat_pointer_unsupported_target_representation", ctx); }
    if std.str_eq(table.target_id, layouts.target.target_id) == 0 || std.str_eq(table.target_triple, layouts.target.target_triple) == 0 || std.str_eq(table.target_id, authority.target_id) == 0 || std.str_eq(table.target_triple, authority.target_triple) == 0 || layouts.target.pointer_size != 8 || layouts.target.pointer_alignment != 8 { return mir_fat_pointer_validation(0, "fat_pointer_unsupported_target_representation", ctx); }
    mut values: std.Vector[MirFatPointerTraitCall[ctx], ctx] := ctx[table.calls]; mut index := 0;
    while index < len(values) {
        mut value := values[index];
        if len(value.call_id) == 0 || len(value.fat_pointer_id) == 0 || len(value.trait_object_id) == 0 || std.str_eq(value.form, "borrowed_trait_object_method_call") == 0 { return mir_fat_pointer_validation(0, "fat_pointer_record_invalid", ctx); }
        if std.str_eq(value.representation, "two_word_data_and_vtable") == 0 { return mir_fat_pointer_validation(0, "fat_pointer_unsupported_target_representation", ctx); }
        if value.metadata_present != 1 || len(value.metadata_component_id) == 0 || len(value.metadata_layout_id) == 0 || len(value.vtable_id) == 0 { return mir_fat_pointer_validation(0, "fat_pointer_missing_metadata", ctx); }
        if std.str_eq(value.pair_id, value.actual_pair_id) == 0 || std.str_eq(value.vtable_id, value.actual_vtable_id) == 0 || std.str_eq(value.data_placement, "fat_pointer.word0.data") == 0 || std.str_eq(value.metadata_placement, "fat_pointer.word1.vtable") == 0 { return mir_fat_pointer_validation(0, "fat_pointer_component_mismatch", ctx); }
        mut data_layout := mir_fat_pointer_layout_by_id(layouts, value.data_layout_id, ctx); mut metadata_layout := mir_fat_pointer_layout_by_id(layouts, value.metadata_layout_id, ctx);
        if data_layout.found == 0 || metadata_layout.found == 0 || std.str_eq(data_layout.layout.type_id, value.data_type_id) == 0 || std.str_eq(metadata_layout.layout.type_id, value.metadata_type_id) == 0 || data_layout.layout.size != 8 || metadata_layout.layout.size != 8 { return mir_fat_pointer_validation(0, "fat_pointer_component_mismatch", ctx); }
        if value.required_alignment != 8 || value.actual_alignment != value.required_alignment || data_layout.layout.alignment != value.required_alignment || metadata_layout.layout.alignment != value.required_alignment { return mir_fat_pointer_validation(0, "fat_pointer_insufficient_alignment", ctx); }
        if len(value.method_signature_id) == 0 || std.str_eq(value.method_signature_id, value.actual_method_signature_id) == 0 { return mir_fat_pointer_validation(0, "fat_pointer_unknown_method_signature", ctx); }
        mut expected := abi.mir_function_abi_by_id(authority, value.call_abi_id, ctx); mut actual := abi.mir_function_abi_by_id(authority, value.actual_call_abi_id, ctx);
        if expected.found == 0 || actual.found == 0 || std.str_eq(expected.value.signature_id, value.method_signature_id) == 0 || std.str_eq(actual.value.signature_id, value.method_signature_id) == 0 { return mir_fat_pointer_validation(0, "fat_pointer_unknown_method_signature", ctx); }
        mut compatibility := abi.mir_validate_abi_compatibility(authority, value.call_abi_id, value.actual_call_abi_id, ctx); if compatibility.compatible == 0 { return mir_fat_pointer_validation(0, "fat_pointer_unknown_method_signature", ctx); }
        if value.slot_ordinal != 0 || len(value.slot_id) == 0 || std.str_eq(value.slot_id, value.actual_slot_id) == 0 { return mir_fat_pointer_validation(0, "fat_pointer_invalid_slot_identity", ctx); }
        if std.str_find(value.operations, "construct_fat_pointer") == 0 - 1 || std.str_find(value.operations, "extract_vtable_method") == 0 - 1 || std.str_find(value.operations, "typed_indirect_call") == 0 - 1 { return mir_fat_pointer_validation(0, "fat_pointer_untyped_dispatch", ctx); }
        if std.str_eq(value.resource_disposition, "borrowed_no_transfer_state_live") == 0 { return mir_fat_pointer_validation(0, "fat_pointer_resource_disposition_mismatch", ctx); }
        if value.expected_result != value.actual_result { return mir_fat_pointer_validation(0, "fat_pointer_method_result_mismatch", ctx); }
        if std.str_eq(value.target_id, table.target_id) == 0 || std.str_eq(value.actual_target_id, table.target_id) == 0 || std.str_eq(value.target_triple, table.target_triple) == 0 || std.str_eq(value.actual_target_triple, table.target_triple) == 0 { return mir_fat_pointer_validation(0, "fat_pointer_unsupported_target_representation", ctx); }
        mut duplicate := index + 1; while duplicate < len(values) { if std.str_eq(values[duplicate].call_id, value.call_id) == 1 || std.str_eq(values[duplicate].fat_pointer_id, value.fat_pointer_id) == 1 { return mir_fat_pointer_validation(0, "fat_pointer_duplicate_identity", ctx); } duplicate = duplicate + 1; }
        index = index + 1;
    }
    return mir_fat_pointer_validation(1, "fat_pointer_abi_valid", ctx);
}

func mir_fat_pointer_field(output: str, key: str, value: str, ctx: &Arena) str { mut result := std.Concat(output, key); result = std.Concat(result, "="); result = std.Concat(result, value); result = std.Concat(result, ";"); return std.Clone(ctx, result); }
func mir_serialize_fat_pointer_abi_for_request(table: MirFatPointerAbiTable[ctx], layouts: layout.MirLayoutTable[ctx], authority: abi.MirFunctionAbiAuthorityTable[ctx], ctx: &Arena) str {
    mut validation := mir_fat_pointer_abi_table_validate(table, layouts, authority, ctx); if validation.valid == 0 { mut invalid := "fat_pointer_format: invalid\nfat_pointer_reason: "; invalid = std.Concat(invalid, validation.reason_code); invalid = std.Concat(invalid, "\n"); return std.Clone(ctx, invalid); }
    mut values: std.Vector[MirFatPointerTraitCall[ctx], ctx] := ctx[table.calls]; mut output := "fat_pointer_format: gust.compiler_fat_pointer_abi.v1\n"; output = std.Concat(output, "fat_pointer_target_id: "); output = std.Concat(output, table.target_id); output = std.Concat(output, "\nfat_pointer_target_triple: "); output = std.Concat(output, table.target_triple); output = std.Concat(output, "\nfat_pointer_call_count: "); output = std.Concat(output, std.FormatInt(len(values))); output = std.Concat(output, "\n");
    mut index := 0; while index < len(values) { mut v := values[index]; mut row := "fat_pointer_call:"; row = mir_fat_pointer_field(row, "id", v.call_id, ctx); row = mir_fat_pointer_field(row, "fat_pointer", v.fat_pointer_id, ctx); row = mir_fat_pointer_field(row, "trait_object", v.trait_object_id, ctx); row = mir_fat_pointer_field(row, "form", v.form, ctx); row = mir_fat_pointer_field(row, "representation", v.representation, ctx); row = mir_fat_pointer_field(row, "data", v.data_component_id, ctx); row = mir_fat_pointer_field(row, "data_type", v.data_type_id, ctx); row = mir_fat_pointer_field(row, "data_layout", v.data_layout_id, ctx); row = mir_fat_pointer_field(row, "data_placement", v.data_placement, ctx); row = mir_fat_pointer_field(row, "metadata", v.metadata_component_id, ctx); row = mir_fat_pointer_field(row, "metadata_type", v.metadata_type_id, ctx); row = mir_fat_pointer_field(row, "metadata_layout", v.metadata_layout_id, ctx); row = mir_fat_pointer_field(row, "metadata_placement", v.metadata_placement, ctx); row = mir_fat_pointer_field(row, "metadata_present", std.FormatInt(v.metadata_present), ctx); row = mir_fat_pointer_field(row, "pair", v.pair_id, ctx); row = mir_fat_pointer_field(row, "actual_pair", v.actual_pair_id, ctx); row = mir_fat_pointer_field(row, "vtable", v.vtable_id, ctx); row = mir_fat_pointer_field(row, "actual_vtable", v.actual_vtable_id, ctx); row = mir_fat_pointer_field(row, "signature", v.method_signature_id, ctx); row = mir_fat_pointer_field(row, "actual_signature", v.actual_method_signature_id, ctx); row = mir_fat_pointer_field(row, "slot", v.slot_id, ctx); row = mir_fat_pointer_field(row, "actual_slot", v.actual_slot_id, ctx); row = mir_fat_pointer_field(row, "slot_ordinal", std.FormatInt(v.slot_ordinal), ctx); row = mir_fat_pointer_field(row, "call_abi", v.call_abi_id, ctx); row = mir_fat_pointer_field(row, "actual_call_abi", v.actual_call_abi_id, ctx); row = mir_fat_pointer_field(row, "operations", v.operations, ctx); row = mir_fat_pointer_field(row, "required_alignment", std.FormatInt(v.required_alignment), ctx); row = mir_fat_pointer_field(row, "actual_alignment", std.FormatInt(v.actual_alignment), ctx); row = mir_fat_pointer_field(row, "resource", v.resource_disposition, ctx); row = mir_fat_pointer_field(row, "expected_result", std.FormatInt(v.expected_result), ctx); row = mir_fat_pointer_field(row, "actual_result", std.FormatInt(v.actual_result), ctx); row = mir_fat_pointer_field(row, "target", v.target_id, ctx); row = mir_fat_pointer_field(row, "actual_target", v.actual_target_id, ctx); row = mir_fat_pointer_field(row, "triple", v.target_triple, ctx); row = mir_fat_pointer_field(row, "actual_triple", v.actual_target_triple, ctx); row = mir_fat_pointer_field(row, "source", v.source_location, ctx); output = std.Concat(output, row); output = std.Concat(output, "\n"); index = index + 1; }
    return std.Clone(ctx, output);
}
