import "mir_function_abi_authority.gst" as abi;
import "mir_typed_indirect_call.gst" as typed;
import "mir_typed_indirect_call_mir_to_c.gst" as mir_to_c;
func fail(message: str) { os.LogStr(message); os.Exit(1); }
func strings(value: str, ctx: &Arena) Index[std.Vector[str, ctx], ctx] { mut result := abi.mir_abi_empty_str_vector(ctx); if len(value) != 0 { result = abi.mir_abi_push_string(result, value, ctx); } return result; }
func function_value(abi_id: str, function_id: str, parameters: Index[std.Vector[str, ctx], ctx], results: Index[std.Vector[str, ctx], ctx], target: str, triple: str, ctx: &Arena) abi.MirFunctionAbiIdentity[ctx] {
    mut value: abi.MirFunctionAbiIdentity[ctx]; value.abi_id = std.Clone(ctx, abi_id); value.function_id = std.Clone(ctx, function_id); value.signature_id = std.Clone(ctx, "sig:scalar_to_scalar"); value.calling_convention = std.Clone(ctx, "gust"); value.target_id = std.Clone(ctx, target); value.target_triple = std.Clone(ctx, triple); value.parameter_placement_ids = parameters; value.result_placement_ids = results; return value;
}
func call_value(id: str, function_value_id: str, form: str, candidates: str, selected: str, expected_abi: str, actual_abi: str, operations: str, target: str, triple: str, ctx: &Arena) typed.MirTypedIndirectCall[ctx] {
    mut value: typed.MirTypedIndirectCall[ctx]; value.call_id = std.Clone(ctx, id); value.function_value_id = std.Clone(ctx, function_value_id); value.form = std.Clone(ctx, form); value.candidate_abi_ids = std.Clone(ctx, candidates); value.selected_function_id = std.Clone(ctx, selected); value.expected_abi_id = std.Clone(ctx, expected_abi); value.actual_abi_id = std.Clone(ctx, actual_abi); value.expected_signature_id = std.Clone(ctx, "sig:scalar_to_scalar"); value.actual_signature_id = std.Clone(ctx, "sig:scalar_to_scalar"); value.expected_parameters = std.Clone(ctx, "abi_placement:scalar:param:0"); value.actual_parameters = std.Clone(ctx, "abi_placement:scalar:param:0"); value.expected_results = std.Clone(ctx, "abi_placement:scalar:result:0"); value.actual_results = std.Clone(ctx, "abi_placement:scalar:result:0"); value.operations = std.Clone(ctx, operations); value.nullability = std.Clone(ctx, "non_null"); value.is_null = 0; value.calling_convention = std.Clone(ctx, "gust"); value.variadic = 0; value.pointer_policy = std.Clone(ctx, "compiler_typed_function_value_no_pointer_cast"); value.resource_transfers = std.Clone(ctx, "non_resource_copy"); value.target_id = std.Clone(ctx, target); value.actual_target_id = std.Clone(ctx, target); value.target_triple = std.Clone(ctx, triple); value.actual_target_triple = std.Clone(ctx, triple); value.source_location = std.Clone(ctx, "compiler/phase16_typed_indirect_call_source.gst:9:5"); return value;
}
func main() {
    mut ctx := os.Arena.New(); defer ctx.Free(); os.SetThreadScratch(ctx); mut target := "target:x86_64-unknown-linux-gnu"; mut triple := "x86_64-unknown-linux-gnu";
    mut parameters := strings("abi_placement:scalar:param:0", &ctx); mut results := strings("abi_placement:scalar:result:0", &ctx);
    mut authority := abi.mir_function_abi_make_empty_table(target, triple, &ctx);
    authority = abi.mir_function_abi_table_with_function(authority, function_value("abi:add", "mir.function.add", parameters, results, target, triple, &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_function(authority, function_value("abi:subtract", "mir.function.subtract", parameters, results, target, triple, &ctx), &ctx);
    mut table := typed.mir_typed_indirect_make_empty_table(target, triple, &ctx);
    table = typed.mir_typed_indirect_table_with_call(table, call_value("typed_call:selection", "function_value:selection", "compatible_function_selection", "abi:add,abi:subtract", "mir.function.subtract", "abi:add", "abi:subtract", "create_typed_function_value,select_compatible_function,typed_indirect_call", target, triple, &ctx), &ctx);
    table = typed.mir_typed_indirect_table_with_call(table, call_value("typed_call:parameter", "function_value:parameter", "typed_function_value_parameter", "abi:add", "mir.function.add", "abi:add", "abi:add", "create_typed_function_value,pass_typed_function_value,typed_indirect_call", target, triple, &ctx), &ctx);
    mut validation := typed.mir_typed_indirect_call_table_validate(table, authority, &ctx); if validation.valid == 0 { fail(std.Concat("Phase 16.6 typed indirect call rejected: ", validation.reason_code)); }
    mut request := typed.mir_serialize_typed_indirect_call_for_request(table, authority, &ctx); mut witness := mir_to_c.mir_typed_indirect_call_mir_to_c_witness(table, authority, &ctx);
    if os.WriteFile("/tmp/gust-phase16-typed-indirect-call.request", request) == 0 || os.WriteFile("/tmp/gust-phase16-typed-indirect-call.mir-to-c.witness", witness) == 0 { fail("Phase 16.6 could not write parity artifacts"); }
    os.LogStr("SUCCESS: Phase 16.6 typed indirect call smoke passed");
}
