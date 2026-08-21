import "mir_function_abi_authority.gst" as abi;
import "mir_function_call.gst" as call_mir;
import "mir_function_call_mir_to_c.gst" as mir_to_c;
import "mir_native_backend_call_mir_request.gst" as call_request;

func fail(message: str) {
    os.LogStr(message);
    os.Exit(1);
}

func strings(first: str, second: str, ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut result := call_mir.mir_call_empty_strings(ctx);
    if len(first) != 0 { result = call_mir.mir_call_push_string(result, first, ctx); }
    if len(second) != 0 { result = call_mir.mir_call_push_string(result, second, ctx); }
    return result;
}

func make_function(abi_id: str, function_id: str, signature_id: str, parameters: Index[std.Vector[str, ctx], ctx], results: Index[std.Vector[str, ctx], ctx], target_id: str, target_triple: str, ctx: &Arena) abi.MirFunctionAbiIdentity[ctx] {
    mut value: abi.MirFunctionAbiIdentity[ctx];
    value.abi_id = std.Clone(ctx, abi_id);
    value.function_id = std.Clone(ctx, function_id);
    value.signature_id = std.Clone(ctx, signature_id);
    value.calling_convention = std.Clone(ctx, "gust");
    value.target_id = std.Clone(ctx, target_id);
    value.target_triple = std.Clone(ctx, target_triple);
    value.parameter_placement_ids = parameters;
    value.result_placement_ids = results;
    return value;
}

func make_declaration(id: str, function_id: str, abi_id: str, signature_id: str, parameters: Index[std.Vector[str, ctx], ctx], results: Index[std.Vector[str, ctx], ctx], target_id: str, target_triple: str, source: str, ctx: &Arena) call_mir.MirFunctionAbiDeclaration[ctx] {
    mut value: call_mir.MirFunctionAbiDeclaration[ctx];
    value.declaration_id = std.Clone(ctx, id);
    value.mir_function_id = std.Clone(ctx, function_id);
    value.abi_id = std.Clone(ctx, abi_id);
    value.signature_id = std.Clone(ctx, signature_id);
    value.parameter_abi_ids = parameters;
    value.result_abi_ids = results;
    value.target_id = std.Clone(ctx, target_id);
    value.target_triple = std.Clone(ctx, target_triple);
    value.calling_convention = std.Clone(ctx, "gust");
    value.source_location = std.Clone(ctx, source);
    return value;
}

func make_classification(id: str, type_id: str, layout_id: str, position: str, value_class: str, register_class: str, size: int, alignment: int, target_id: str, target_triple: str, ctx: &Arena) abi.MirAbiValueClassification[ctx] {
    mut value: abi.MirAbiValueClassification[ctx];
    value.classification_id = std.Clone(ctx, id);
    value.type_id = std.Clone(ctx, type_id);
    value.layout_id = std.Clone(ctx, layout_id);
    value.position = std.Clone(ctx, position);
    value.value_class = std.Clone(ctx, value_class);
    value.register_class = std.Clone(ctx, register_class);
    value.size_bytes = size;
    value.align_bytes = alignment;
    value.target_id = std.Clone(ctx, target_id);
    value.target_triple = std.Clone(ctx, target_triple);
    return value;
}

func make_parameter_placement(id: str, function_abi: str, parameter_id: str, ordinal: int, classification_id: str, mode: str, layout_id: str, ctx: &Arena) abi.MirAbiParameterPlacement[ctx] {
    mut value: abi.MirAbiParameterPlacement[ctx];
    value.placement_id = std.Clone(ctx, id);
    value.abi_id = std.Clone(ctx, function_abi);
    value.parameter_id = std.Clone(ctx, parameter_id);
    value.ordinal = ordinal;
    value.classification_id = std.Clone(ctx, classification_id);
    value.passing_mode = std.Clone(ctx, mode);
    value.location = std.Clone(ctx, "canonical_call_operand");
    value.layout_id = std.Clone(ctx, layout_id);
    value.resource_id = std.Clone(ctx, "");
    value.hidden = 0;
    return value;
}

func make_result_placement(id: str, function_abi: str, result_id: str, classification_id: str, mode: str, layout_id: str, ctx: &Arena) abi.MirAbiResultPlacement[ctx] {
    mut value: abi.MirAbiResultPlacement[ctx];
    value.placement_id = std.Clone(ctx, id);
    value.abi_id = std.Clone(ctx, function_abi);
    value.result_id = std.Clone(ctx, result_id);
    value.ordinal = 0;
    value.classification_id = std.Clone(ctx, classification_id);
    value.passing_mode = std.Clone(ctx, mode);
    value.location = std.Clone(ctx, "hidden_result_pointer");
    value.layout_id = std.Clone(ctx, layout_id);
    value.resource_id = std.Clone(ctx, "");
    value.hidden = 1;
    return value;
}

func make_operand(id: str, call_id: str, abi_value_id: str, ordinal: int, value_id: str, value_type: str, layout_id: str, passing_mode: str, evaluation: int, hidden: int, ctx: &Arena) call_mir.MirCallOperand[ctx] {
    mut value: call_mir.MirCallOperand[ctx];
    value.operand_id = std.Clone(ctx, id);
    value.call_id = std.Clone(ctx, call_id);
    value.abi_value_id = std.Clone(ctx, abi_value_id);
    value.ordinal = ordinal;
    value.value_id = std.Clone(ctx, value_id);
    value.value_type_id = std.Clone(ctx, value_type);
    value.layout_id = std.Clone(ctx, layout_id);
    value.passing_mode = std.Clone(ctx, passing_mode);
    value.materialization = std.Clone(ctx, abi.mir_abi_argument_materialization(passing_mode));
    value.evaluation_order = evaluation;
    value.hidden = hidden;
    value.resource_id = std.Clone(ctx, "");
    value.resource_transition_id = std.Clone(ctx, "");
    value.resource_state_before = std.Clone(ctx, "");
    value.resource_state_after = std.Clone(ctx, "");
    value.source_location = std.Clone(ctx, "compiler/phase16_call_mir_source.gst:8:9");
    return value;
}

func make_operation(id: str, kind_tag: int, call_id: str, caller_abi: str, callee_abi: str, plan_id: str, arguments: Index[std.Vector[str, ctx], ctx], results: Index[std.Vector[str, ctx], ctx], input: str, output: str, target_id: str, target_triple: str, ctx: &Arena) call_mir.MirCallOperation[ctx] {
    mut value: call_mir.MirCallOperation[ctx];
    value.operation_id = std.Clone(ctx, id);
    unsafe { value.operation_kind.tag = kind_tag; }
    value.call_id = std.Clone(ctx, call_id);
    value.caller_abi_id = std.Clone(ctx, caller_abi);
    value.callee_abi_id = std.Clone(ctx, callee_abi);
    value.call_plan_id = std.Clone(ctx, plan_id);
    value.argument_abi_ids = arguments;
    value.result_abi_ids = results;
    value.input_value_id = std.Clone(ctx, input);
    value.output_value_id = std.Clone(ctx, output);
    value.target_id = std.Clone(ctx, target_id);
    value.target_triple = std.Clone(ctx, target_triple);
    value.calling_convention = std.Clone(ctx, "gust");
    value.source_location = std.Clone(ctx, "compiler/phase16_call_mir_source.gst:8:5");
    return value;
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut target_id := "target:x86_64-unknown-linux-gnu";
    mut target_triple := "x86_64-unknown-linux-gnu";
    mut caller_abi := "function_abi:v1:phase16:main";
    mut callee_abi := "function_abi:v1:phase16:add";
    mut call_id := "call:phase16:add";
    mut plan_id := "abi_call_plan:v1:phase16:add";
    mut parameter_zero := "abi_placement:v1:phase16:add:param:0";
    mut parameter_one := "abi_placement:v1:phase16:add:param:1";
    mut result_zero := "abi_placement:v1:phase16:add:result:0";
    mut argument_ids := strings(parameter_zero, parameter_one, &ctx);
    mut result_ids := strings(result_zero, "", &ctx);

    mut authority := abi.mir_function_abi_make_empty_table(target_id, target_triple, &ctx);
    authority = abi.mir_function_abi_table_with_classification(authority, make_classification("classification:phase19:str", "type:gust:str", "layout:string_view", "parameter", "string_view", "aggregate", 16, 8, target_id, target_triple, &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_classification(authority, make_classification("classification:phase19:arena", "type:gust:Arena", "layout:os:Arena", "parameter", "arena", "memory", 32, 8, target_id, target_triple, &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_classification(authority, make_classification("classification:phase19:int", "type:gust:int", "layout:primitive:int", "hidden_result", "integer", "integer", 4, 4, target_id, target_triple, &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_function(authority, make_function(caller_abi, "mir.function.main", "signature:main:returns_int", strings("", "", &ctx), result_ids, target_id, target_triple, &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_function(authority, make_function(callee_abi, "mir.function.add", "signature:add:int_int_to_int", argument_ids, result_ids, target_id, target_triple, &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_parameter(authority, make_parameter_placement(parameter_zero, callee_abi, "parameter:phase16:add:0", 0, "classification:phase19:str", "direct", "layout:string_view", &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_parameter(authority, make_parameter_placement(parameter_one, callee_abi, "parameter:phase16:add:1", 1, "classification:phase19:arena", "indirect_by_reference", "layout:os:Arena", &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_result(authority, make_result_placement(result_zero, callee_abi, "result:phase16:add:0", "classification:phase19:int", "hidden_pointer", "layout:primitive:int", &ctx), &ctx);
    mut plan: abi.MirAbiCallSitePlan[ctx];
    plan.call_plan_id = plan_id;
    plan.call_site_id = call_id;
    plan.caller_function_id = "mir.function.main";
    plan.callee_function_id = "mir.function.add";
    plan.expected_abi_id = callee_abi;
    plan.actual_abi_id = callee_abi;
    plan.argument_placement_ids = argument_ids;
    plan.result_placement_ids = result_ids;
    plan.signature_compatible = 1;
    plan.target_id = target_id;
    plan.target_triple = target_triple;
    authority = abi.mir_function_abi_table_with_call_plan(authority, plan, &ctx);

    mut table := call_mir.mir_function_call_make_empty_table(target_id, target_triple, &ctx);
    table = call_mir.mir_function_call_table_with_declaration(table, make_declaration("declaration:phase16:main", "mir.function.main", caller_abi, "signature:main:returns_int", strings("", "", &ctx), result_ids, target_id, target_triple, "compiler/phase16_call_mir_source.gst:3:1", &ctx), &ctx);
    table = call_mir.mir_function_call_table_with_declaration(table, make_declaration("declaration:phase16:add", "mir.function.add", callee_abi, "signature:add:int_int_to_int", argument_ids, result_ids, target_id, target_triple, "compiler/phase16_call_mir_source.gst:7:1", &ctx), &ctx);
    table = call_mir.mir_function_call_table_with_operand(table, make_operand("operand:phase16:add:0", call_id, parameter_zero, 0, "mir.value.local.a", "type:gust:str", "layout:string_view", "direct", 0, 0, &ctx), &ctx);
    table = call_mir.mir_function_call_table_with_operand(table, make_operand("operand:phase16:add:1", call_id, parameter_one, 1, "mir.value.index.arena", "type:gust:Arena", "layout:os:Arena", "indirect_by_reference", 1, 0, &ctx), &ctx);
    table = call_mir.mir_function_call_table_with_operand(table, make_operand("operand:phase16:hidden-result", call_id, result_zero, 0, "mir.value.hidden.result", "type:gust:int", "layout:primitive:int", "hidden_pointer", 2, 1, &ctx), &ctx);

    table = call_mir.mir_function_call_table_with_operation(table, make_operation("operation:phase16:function-declaration", 0, call_id, caller_abi, callee_abi, plan_id, argument_ids, result_ids, "", "", target_id, target_triple, &ctx), &ctx);
    table = call_mir.mir_function_call_table_with_operation(table, make_operation("operation:phase16:argument-materialization", 1, call_id, caller_abi, callee_abi, plan_id, argument_ids, result_ids, "operand:phase16:add:0", "", target_id, target_triple, &ctx), &ctx);
    table = call_mir.mir_function_call_table_with_operation(table, make_operation("operation:phase16:direct-call", 2, call_id, caller_abi, callee_abi, plan_id, argument_ids, result_ids, "", "mir.value.call.result", target_id, target_triple, &ctx), &ctx);
    table = call_mir.mir_function_call_table_with_operation(table, make_operation("operation:phase16:result-extraction", 3, call_id, caller_abi, callee_abi, plan_id, argument_ids, result_ids, "mir.value.call.result", "mir.value.result.extracted", target_id, target_triple, &ctx), &ctx);
    table = call_mir.mir_function_call_table_with_operation(table, make_operation("operation:phase16:hidden-argument", 4, call_id, caller_abi, callee_abi, plan_id, argument_ids, result_ids, "operand:phase16:hidden-result", "", target_id, target_triple, &ctx), &ctx);
    table = call_mir.mir_function_call_table_with_operation(table, make_operation("operation:phase16:hidden-result-storage", 5, call_id, caller_abi, callee_abi, plan_id, argument_ids, result_ids, "operand:phase16:hidden-result", "mir.value.hidden.result", target_id, target_triple, &ctx), &ctx);
    table = call_mir.mir_function_call_table_with_operation(table, make_operation("operation:phase16:post-call-normalization", 6, call_id, caller_abi, callee_abi, plan_id, argument_ids, result_ids, "mir.value.result.extracted", "mir.value.result.normalized", target_id, target_triple, &ctx), &ctx);

    mut validation := call_mir.mir_function_call_table_validate(table, authority, &ctx);
    if validation.valid == 0 { fail(std.Concat("Phase 16.2 call MIR rejected: ", validation.reason_code)); }
    mut c_emission := mir_to_c.mir_function_call_to_c_source(table, authority, &ctx);
    if c_emission.success == 0 || std.str_find(c_emission.c_source, "gust_call_") == 0 - 1 {
        fail("Phase 16.2 MIR-to-C did not consume canonical call operations");
    }
    mut request := call_mir.mir_serialize_function_call_for_request(table, authority, &ctx);
    mut witness := mir_to_c.mir_function_call_mir_to_c_witness(table, authority, &ctx);
    if os.WriteFile("/tmp/gust-phase16-call-mir.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase16-call-mir.mir-to-c.witness", witness) == 0
    {
        fail("Phase 16.2 could not write parity artifacts");
    }
    os.LogStr("SUCCESS: Phase 16.2 canonical call MIR smoke passed");
}
