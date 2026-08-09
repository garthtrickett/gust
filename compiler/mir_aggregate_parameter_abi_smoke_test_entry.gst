import "mir_layout.gst" as layout;
import "mir_function_abi_authority.gst" as abi;
import "mir_aggregate_parameter_abi.gst" as aggregate_parameter;
import "mir_aggregate_parameter_abi_mir_to_c.gst" as mir_to_c;
import "mir_native_backend_aggregate_parameter_request.gst" as native_request;

func fail(message: str) { os.LogStr(message); os.Exit(1); }

func strings(first: str, second: str, third: str, fourth: str, ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut values := abi.mir_abi_empty_str_vector(ctx);
    if len(first) != 0 { values = abi.mir_abi_push_string(values, first, ctx); }
    if len(second) != 0 { values = abi.mir_abi_push_string(values, second, ctx); }
    if len(third) != 0 { values = abi.mir_abi_push_string(values, third, ctx); }
    if len(fourth) != 0 { values = abi.mir_abi_push_string(values, fourth, ctx); }
    return values;
}

func make_classification(id: str, type_id: str, layout_id: str, mode: str, size: int, alignment: int, target_id: str, target_triple: str, ctx: &Arena) abi.MirAbiValueClassification[ctx] {
    mut value: abi.MirAbiValueClassification[ctx];
    value.classification_id = std.Clone(ctx, id);
    value.type_id = std.Clone(ctx, type_id);
    value.layout_id = std.Clone(ctx, layout_id);
    value.position = "parameter";
    value.value_class = "aggregate";
    value.register_class = std.Clone(ctx, mode);
    value.size_bytes = size;
    value.align_bytes = alignment;
    value.target_id = std.Clone(ctx, target_id);
    value.target_triple = std.Clone(ctx, target_triple);
    return value;
}

func make_placement(id: str, function_abi: str, parameter_id: str, ordinal: int, classification_id: str, mode: str, logical_location: str, layout_id: str, ctx: &Arena) abi.MirAbiParameterPlacement[ctx] {
    mut value: abi.MirAbiParameterPlacement[ctx];
    value.placement_id = std.Clone(ctx, id);
    value.abi_id = std.Clone(ctx, function_abi);
    value.parameter_id = std.Clone(ctx, parameter_id);
    value.ordinal = ordinal;
    value.classification_id = std.Clone(ctx, classification_id);
    value.passing_mode = std.Clone(ctx, mode);
    value.location = std.Clone(ctx, logical_location);
    value.layout_id = std.Clone(ctx, layout_id);
    value.resource_id = "";
    value.hidden = 0;
    return value;
}

func make_plan(id: str, function_abi: str, placement: str, parameter_id: str, ordinal: int, type_id: str, layout_id: str, abi_value: str, shape: str, mode: str, size: int, alignment: int, caller: str, callee: str, initialized: str, target_id: str, target_triple: str, ctx: &Arena) aggregate_parameter.MirAggregateParameterPlan[ctx] {
    mut value: aggregate_parameter.MirAggregateParameterPlan[ctx];
    value.plan_id = std.Clone(ctx, id);
    value.function_abi_id = std.Clone(ctx, function_abi);
    value.parameter_placement_id = std.Clone(ctx, placement);
    value.parameter_id = std.Clone(ctx, parameter_id);
    value.argument_ordinal = ordinal;
    value.canonical_type_id = std.Clone(ctx, type_id);
    value.layout_id = std.Clone(ctx, layout_id);
    value.abi_value_id = std.Clone(ctx, abi_value);
    value.shape = std.Clone(ctx, shape);
    value.passing_mode = std.Clone(ctx, mode);
    value.size_bytes = size;
    value.align_bytes = alignment;
    value.caller_materialization = std.Clone(ctx, caller);
    value.callee_materialization = std.Clone(ctx, callee);
    value.padding_policy = "initialized_fields_only_padding_not_semantic";
    value.resource_disposition = "non_resource";
    value.transfer_disposition = "copy";
    value.resource_id = "";
    value.initialized_byte_ranges = std.Clone(ctx, initialized);
    value.target_id = std.Clone(ctx, target_id);
    value.target_triple = std.Clone(ctx, target_triple);
    return value;
}

func make_location(id: str, plan: str, ordinal: int, logical_location: str, offset: int, size: int, alignment: int, initialized_value: int, ctx: &Arena) aggregate_parameter.MirAggregateParameterLocation[ctx] {
    mut value: aggregate_parameter.MirAggregateParameterLocation[ctx];
    value.location_id = std.Clone(ctx, id);
    value.plan_id = std.Clone(ctx, plan);
    value.logical_ordinal = ordinal;
    value.logical_location = std.Clone(ctx, logical_location);
    value.byte_offset = offset;
    value.byte_size = size;
    value.required_alignment = alignment;
    value.initialized_value = initialized_value;
    return value;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut target_id := "target:x86_64-unknown-linux-gnu";
    mut target_triple := "x86_64-unknown-linux-gnu";
    mut target := layout.mir_layout_make_target_v2(target_id, target_triple, "little", 8, 8, 4, 8, 16, &ctx);
    mut layouts := layout.mir_layout_make_table(target, &ctx);
    mut i32_layout := layout.mir_layout_make_scalar_type_layout("type:gust:i32", target_id, "primitive", 4, 4, 32, "signed", "any_bit_pattern", &ctx);
    mut i64_layout := layout.mir_layout_make_scalar_type_layout("type:gust:i64", target_id, "primitive", 8, 8, 64, "signed", "any_bit_pattern", &ctx);
    layouts = layout.mir_layout_table_with_layout(layouts, i32_layout, &ctx);
    layouts = layout.mir_layout_table_with_layout(layouts, i64_layout, &ctx);

    mut direct_layout := layout.mir_layout_make_type_layout("type:phase16:DirectI32", target_id, "struct", 4, 4, 4, &ctx);
    direct_layout.bit_width = 32;
    direct_layout.validity_kind = "any_bit_pattern";
    direct_layout = layout.mir_layout_type_with_field(direct_layout, layout.mir_layout_make_field("field:direct:value", "value", "type:gust:i32", i32_layout.layout_id, 0, 4, 4, &ctx), &ctx);
    layouts = layout.mir_layout_table_with_layout(layouts, direct_layout, &ctx);
    mut split_layout := layout.mir_layout_make_type_layout("type:phase16:PairI32", target_id, "struct", 8, 4, 8, &ctx);
    split_layout.bit_width = 64;
    split_layout.validity_kind = "any_bit_pattern";
    split_layout = layout.mir_layout_type_with_field(split_layout, layout.mir_layout_make_field("field:pair:left", "left", "type:gust:i32", i32_layout.layout_id, 0, 4, 4, &ctx), &ctx);
    split_layout = layout.mir_layout_type_with_field(split_layout, layout.mir_layout_make_field("field:pair:right", "right", "type:gust:i32", i32_layout.layout_id, 4, 4, 4, &ctx), &ctx);
    layouts = layout.mir_layout_table_with_layout(layouts, split_layout, &ctx);
    mut indirect_layout := layout.mir_layout_make_type_layout("type:phase16:TripleI64", target_id, "struct", 24, 8, 24, &ctx);
    indirect_layout.bit_width = 192;
    indirect_layout.validity_kind = "any_bit_pattern";
    indirect_layout = layout.mir_layout_type_with_field(indirect_layout, layout.mir_layout_make_field("field:triple:first", "first", "type:gust:i64", i64_layout.layout_id, 0, 8, 8, &ctx), &ctx);
    indirect_layout = layout.mir_layout_type_with_field(indirect_layout, layout.mir_layout_make_field("field:triple:second", "second", "type:gust:i64", i64_layout.layout_id, 8, 8, 8, &ctx), &ctx);
    indirect_layout = layout.mir_layout_type_with_field(indirect_layout, layout.mir_layout_make_field("field:triple:third", "third", "type:gust:i64", i64_layout.layout_id, 16, 8, 8, &ctx), &ctx);
    layouts = layout.mir_layout_table_with_layout(layouts, indirect_layout, &ctx);
    if layout.mir_layout_table_is_valid(layouts, &ctx) == 0 { fail("Phase 16.3 fixture layout table invalid"); }

    mut function_abi := "function_abi:v1:phase16:aggregate_parameters";
    mut direct_class := "abi_classification:v1:phase16:direct";
    mut split_class := "abi_classification:v1:phase16:split";
    mut indirect_class := "abi_classification:v1:phase16:indirect";
    mut direct_place := "abi_placement:v1:phase16:aggregate:param:1";
    mut split_place := "abi_placement:v1:phase16:aggregate:param:2";
    mut indirect_place := "abi_placement:v1:phase16:aggregate:param:3";
    mut authority := abi.mir_function_abi_make_empty_table(target_id, target_triple, &ctx);
    authority = abi.mir_function_abi_table_with_classification(authority, make_classification(direct_class, direct_layout.type_id, direct_layout.layout_id, "direct", 4, 4, target_id, target_triple, &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_classification(authority, make_classification(split_class, split_layout.type_id, split_layout.layout_id, "split", 8, 4, target_id, target_triple, &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_classification(authority, make_classification(indirect_class, indirect_layout.type_id, indirect_layout.layout_id, "indirect_by_value", 24, 8, target_id, target_triple, &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_parameter(authority, make_placement(direct_place, function_abi, "parameter:direct", 1, direct_class, "direct", "canonical_value:1", direct_layout.layout_id, &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_parameter(authority, make_placement(split_place, function_abi, "parameter:split", 2, split_class, "split", "canonical_value:2,canonical_value:3", split_layout.layout_id, &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_parameter(authority, make_placement(indirect_place, function_abi, "parameter:indirect", 3, indirect_class, "indirect_by_value", "caller_owned_readonly_slot:4", indirect_layout.layout_id, &ctx), &ctx);

    mut function: abi.MirFunctionAbiIdentity[ctx];
    function.abi_id = function_abi;
    function.function_id = "mir.function.aggregate_parameters";
    function.signature_id = "signature:scalar_direct_split_indirect_to_int";
    function.calling_convention = "gust";
    function.target_id = target_id;
    function.target_triple = target_triple;
    function.parameter_placement_ids = strings(direct_place, split_place, indirect_place, "", &ctx);
    function.result_placement_ids = strings("", "", "", "", &ctx);
    authority = abi.mir_function_abi_table_with_function(authority, function, &ctx);

    mut table := aggregate_parameter.mir_aggregate_parameter_make_empty_table(target_id, target_triple, &ctx);
    table = aggregate_parameter.mir_aggregate_parameter_table_with_plan(table, make_plan("aggregate_parameter_plan:direct", function_abi, direct_place, "parameter:direct", 1, direct_layout.type_id, direct_layout.layout_id, direct_class, "struct_single_i32", "direct", 4, 4, "canonical_value", "canonical_value", "0..4", target_id, target_triple, &ctx), &ctx);
    table = aggregate_parameter.mir_aggregate_parameter_table_with_plan(table, make_plan("aggregate_parameter_plan:split", function_abi, split_place, "parameter:split", 2, split_layout.type_id, split_layout.layout_id, split_class, "struct_pair_i32", "split", 8, 4, "split_initialized_fields", "join_initialized_fields", "0..4,4..8", target_id, target_triple, &ctx), &ctx);
    table = aggregate_parameter.mir_aggregate_parameter_table_with_plan(table, make_plan("aggregate_parameter_plan:indirect", function_abi, indirect_place, "parameter:indirect", 3, indirect_layout.type_id, indirect_layout.layout_id, indirect_class, "struct_triple_i64", "indirect_by_value", 24, 8, "caller_owned_readonly_slot", "read_indirect_by_value", "0..8,8..16,16..24", target_id, target_triple, &ctx), &ctx);
    table = aggregate_parameter.mir_aggregate_parameter_table_with_location(table, make_location("aggregate_parameter_location:direct:0", "aggregate_parameter_plan:direct", 0, "canonical_value:1", 0, 4, 4, 11, &ctx), &ctx);
    table = aggregate_parameter.mir_aggregate_parameter_table_with_location(table, make_location("aggregate_parameter_location:split:0", "aggregate_parameter_plan:split", 0, "canonical_value:2", 0, 4, 4, 13, &ctx), &ctx);
    table = aggregate_parameter.mir_aggregate_parameter_table_with_location(table, make_location("aggregate_parameter_location:split:1", "aggregate_parameter_plan:split", 1, "canonical_value:3", 4, 4, 4, 17, &ctx), &ctx);
    table = aggregate_parameter.mir_aggregate_parameter_table_with_location(table, make_location("aggregate_parameter_location:indirect:0", "aggregate_parameter_plan:indirect", 0, "caller_owned_readonly_slot:4", 0, 24, 8, 19, &ctx), &ctx);

    mut validation := aggregate_parameter.mir_aggregate_parameter_table_validate(table, layouts, authority, &ctx);
    if validation.valid == 0 { fail(std.Concat("Phase 16.3 aggregate parameter table rejected: ", validation.reason_code)); }
    mut c_emission := mir_to_c.mir_aggregate_parameter_to_c_source(table, layouts, authority, &ctx);
    if c_emission.success == 0 || std.str_find(c_emission.c_source, "mode=split") == 0 - 1 { fail("Phase 16.3 MIR-to-C did not consume aggregate parameter plans"); }
    mut request: native_request.MirNativeBackendAggregateParameterRequest[ctx];
    request.target_triple = target_triple;
    request.layout_table = layouts;
    request.abi_authority = authority;
    request.aggregate_parameter_table = table;
    mut serialized := native_request.mir_serialize_native_backend_aggregate_parameter_request(request, &ctx);
    mut witness := mir_to_c.mir_aggregate_parameter_mir_to_c_witness(table, layouts, authority, &ctx);
    if os.WriteFile("/tmp/gust-phase16-aggregate-parameter.request", serialized) == 0 || os.WriteFile("/tmp/gust-phase16-aggregate-parameter.mir-to-c.witness", witness) == 0 { fail("Phase 16.3 could not write parity artifacts"); }
    os.LogStr("SUCCESS: Phase 16.3 aggregate parameter ABI smoke passed");
}
