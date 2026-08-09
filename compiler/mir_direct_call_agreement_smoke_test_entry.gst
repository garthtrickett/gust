import "mir_function_abi_authority.gst" as abi;
import "mir_function_call.gst" as calls;
import "mir_direct_call_agreement.gst" as direct;
import "mir_direct_call_agreement_mir_to_c.gst" as mir_to_c;

func fail(message: str) { os.LogStr(message); os.Exit(1); }

func strings(first: str, second: str, ctx: &Arena) Index[std.Vector[str, ctx], ctx] {
    mut result := calls.mir_call_empty_strings(ctx);
    if len(first) != 0 { result = calls.mir_call_push_string(result, first, ctx); }
    if len(second) != 0 { result = calls.mir_call_push_string(result, second, ctx); }
    return result;
}

func function_value(id: str, function_id: str, signature: str, parameters: Index[std.Vector[str, ctx], ctx], results: Index[std.Vector[str, ctx], ctx], target: str, triple: str, ctx: &Arena) abi.MirFunctionAbiIdentity[ctx] {
    mut value: abi.MirFunctionAbiIdentity[ctx]; value.abi_id = std.Clone(ctx, id); value.function_id = std.Clone(ctx, function_id);
    value.signature_id = std.Clone(ctx, signature); value.calling_convention = std.Clone(ctx, "gust"); value.target_id = std.Clone(ctx, target);
    value.target_triple = std.Clone(ctx, triple); value.parameter_placement_ids = parameters; value.result_placement_ids = results; return value;
}

func declaration_value(id: str, function_id: str, abi_id: str, signature: str, parameters: Index[std.Vector[str, ctx], ctx], results: Index[std.Vector[str, ctx], ctx], target: str, triple: str, ctx: &Arena) calls.MirFunctionAbiDeclaration[ctx] {
    mut value: calls.MirFunctionAbiDeclaration[ctx]; value.declaration_id = std.Clone(ctx, id); value.mir_function_id = std.Clone(ctx, function_id);
    value.abi_id = std.Clone(ctx, abi_id); value.signature_id = std.Clone(ctx, signature); value.parameter_abi_ids = parameters; value.result_abi_ids = results;
    value.target_id = std.Clone(ctx, target); value.target_triple = std.Clone(ctx, triple); value.calling_convention = std.Clone(ctx, "gust");
    value.source_location = std.Clone(ctx, "compiler/phase16_direct_call_agreement_source.gst:1:1"); return value;
}

func add_plan(table: abi.MirFunctionAbiAuthorityTable[ctx], id: str, call_id: str, caller: str, callee: str, callee_abi: str, arguments: Index[std.Vector[str, ctx], ctx], results: Index[std.Vector[str, ctx], ctx], target: str, triple: str, ctx: &Arena) abi.MirFunctionAbiAuthorityTable[ctx] {
    mut plan: abi.MirAbiCallSitePlan[ctx]; plan.call_plan_id = std.Clone(ctx, id); plan.call_site_id = std.Clone(ctx, call_id);
    plan.caller_function_id = std.Clone(ctx, caller); plan.callee_function_id = std.Clone(ctx, callee); plan.expected_abi_id = std.Clone(ctx, callee_abi);
    plan.actual_abi_id = std.Clone(ctx, callee_abi); plan.argument_placement_ids = arguments; plan.result_placement_ids = results; plan.signature_compatible = 1;
    plan.target_id = std.Clone(ctx, target); plan.target_triple = std.Clone(ctx, triple); return abi.mir_function_abi_table_with_call_plan(table, plan, ctx);
}

func agreement(id: str, call_id: str, kind: str, caller: str, callee: str, plan: str, abi_id: str, signature: str, parameters: str, results: str, layouts: str, classes: str, hidden: str, flow: str, target: str, triple: str, ctx: &Arena) direct.MirDirectCallAgreement[ctx] {
    mut value: direct.MirDirectCallAgreement[ctx]; value.agreement_id = std.Clone(ctx, id); value.call_id = std.Clone(ctx, call_id);
    value.composition_kind = std.Clone(ctx, kind); value.caller_function_id = std.Clone(ctx, caller); value.callee_function_id = std.Clone(ctx, callee);
    value.call_plan_id = std.Clone(ctx, plan); value.declaration_abi_id = std.Clone(ctx, abi_id); value.definition_abi_id = std.Clone(ctx, abi_id);
    value.expected_abi_id = std.Clone(ctx, abi_id); value.actual_abi_id = std.Clone(ctx, abi_id); value.expected_signature_id = std.Clone(ctx, signature);
    value.actual_signature_id = std.Clone(ctx, signature); value.expected_calling_convention = std.Clone(ctx, "gust"); value.actual_calling_convention = std.Clone(ctx, "gust");
    value.expected_parameters = std.Clone(ctx, parameters); value.actual_parameters = std.Clone(ctx, parameters); value.expected_results = std.Clone(ctx, results);
    value.actual_results = std.Clone(ctx, results); value.expected_layouts = std.Clone(ctx, layouts); value.actual_layouts = std.Clone(ctx, layouts);
    value.expected_classes = std.Clone(ctx, classes); value.actual_classes = std.Clone(ctx, classes); value.expected_extensions = std.Clone(ctx, "none");
    value.actual_extensions = std.Clone(ctx, "none"); value.expected_hidden_result = std.Clone(ctx, hidden); value.actual_hidden_result = std.Clone(ctx, hidden);
    value.expected_resource_transfers = std.Clone(ctx, "non_resource_copy"); value.actual_resource_transfers = std.Clone(ctx, "non_resource_copy");
    value.result_flow = std.Clone(ctx, flow); value.freshness = std.Clone(ctx, "current_compiler_plan"); value.compatible = 1;
    value.target_id = std.Clone(ctx, target); value.actual_target_id = std.Clone(ctx, target); value.target_triple = std.Clone(ctx, triple);
    value.actual_target_triple = std.Clone(ctx, triple); value.source_location = std.Clone(ctx, "compiler/phase16_direct_call_agreement_source.gst:8:5"); return value;
}

func main() {
    mut ctx := os.Arena.New(); defer ctx.Free(); os.SetThreadScratch(ctx);
    mut target := "target:x86_64-unknown-linux-gnu"; mut triple := "x86_64-unknown-linux-gnu";
    mut scalar_param := "abi_placement:v1:phase16:scalar:param:0"; mut scalar_result := "abi_placement:v1:phase16:scalar:result:0";
    mut aggregate_param := "abi_placement:v1:phase16:pair:param:1"; mut aggregate_result := "abi_placement:v1:phase16:pair:result:0";
    mut hidden_result := "abi_placement:v1:phase16:triple:hidden:0";
    mut scalar_args := strings(scalar_param, "", &ctx); mut scalar_results := strings(scalar_result, "", &ctx);
    mut mixed_args := strings(scalar_param, aggregate_param, &ctx); mut aggregate_results := strings(aggregate_result, "", &ctx);
    mut aggregate_args := strings(aggregate_result, "", &ctx); mut hidden_results := strings(hidden_result, "", &ctx);

    mut authority := abi.mir_function_abi_make_empty_table(target, triple, &ctx);
    authority = abi.mir_function_abi_table_with_function(authority, function_value("abi:main", "mir.function.main", "sig:main", strings("", "", &ctx), scalar_results, target, triple, &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_function(authority, function_value("abi:add", "mir.function.add", "sig:add:scalar", scalar_args, scalar_results, target, triple, &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_function(authority, function_value("abi:recurse", "mir.function.recurse", "sig:recurse:scalar", scalar_args, scalar_results, target, triple, &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_function(authority, function_value("abi:mix", "mir.function.mix", "sig:mix:scalar_pair", mixed_args, aggregate_results, target, triple, &ctx), &ctx);
    authority = abi.mir_function_abi_table_with_function(authority, function_value("abi:consume", "mir.function.consume", "sig:consume:pair_to_triple", aggregate_args, hidden_results, target, triple, &ctx), &ctx);
    authority = add_plan(authority, "plan:nested", "call:nested", "mir.function.main", "mir.function.add", "abi:add", scalar_args, scalar_results, target, triple, &ctx);
    authority = add_plan(authority, "plan:recursive", "call:recursive", "mir.function.recurse", "mir.function.recurse", "abi:recurse", scalar_args, scalar_results, target, triple, &ctx);
    authority = add_plan(authority, "plan:mixed", "call:mixed", "mir.function.main", "mir.function.mix", "abi:mix", mixed_args, aggregate_results, target, triple, &ctx);
    authority = add_plan(authority, "plan:chain", "call:chain", "mir.function.main", "mir.function.consume", "abi:consume", aggregate_args, hidden_results, target, triple, &ctx);

    mut call_table := calls.mir_function_call_make_empty_table(target, triple, &ctx);
    call_table = calls.mir_function_call_table_with_declaration(call_table, declaration_value("decl:main", "mir.function.main", "abi:main", "sig:main", strings("", "", &ctx), scalar_results, target, triple, &ctx), &ctx);
    call_table = calls.mir_function_call_table_with_declaration(call_table, declaration_value("decl:add", "mir.function.add", "abi:add", "sig:add:scalar", scalar_args, scalar_results, target, triple, &ctx), &ctx);
    call_table = calls.mir_function_call_table_with_declaration(call_table, declaration_value("decl:recurse", "mir.function.recurse", "abi:recurse", "sig:recurse:scalar", scalar_args, scalar_results, target, triple, &ctx), &ctx);
    call_table = calls.mir_function_call_table_with_declaration(call_table, declaration_value("decl:mix", "mir.function.mix", "abi:mix", "sig:mix:scalar_pair", mixed_args, aggregate_results, target, triple, &ctx), &ctx);
    call_table = calls.mir_function_call_table_with_declaration(call_table, declaration_value("decl:consume", "mir.function.consume", "abi:consume", "sig:consume:pair_to_triple", aggregate_args, hidden_results, target, triple, &ctx), &ctx);

    mut table := direct.mir_direct_call_make_empty_table(target, triple, &ctx);
    table = direct.mir_direct_call_table_with_agreement(table, agreement("agreement:nested", "call:nested", "nested_direct", "mir.function.main", "mir.function.add", "plan:nested", "abi:add", "sig:add:scalar", scalar_param, scalar_result, "layout:i32->layout:i32", "direct->direct", "none", "nested_result", target, triple, &ctx), &ctx);
    table = direct.mir_direct_call_table_with_agreement(table, agreement("agreement:recursive", "call:recursive", "direct_recursion", "mir.function.recurse", "mir.function.recurse", "plan:recursive", "abi:recurse", "sig:recurse:scalar", scalar_param, scalar_result, "layout:i32->layout:i32", "direct->direct", "none", "recursive_result", target, triple, &ctx), &ctx);
    table = direct.mir_direct_call_table_with_agreement(table, agreement("agreement:mixed", "call:mixed", "mixed_scalar_aggregate", "mir.function.main", "mir.function.mix", "plan:mixed", "abi:mix", "sig:mix:scalar_pair", "abi_placement:v1:phase16:scalar:param:0,abi_placement:v1:phase16:pair:param:1", aggregate_result, "layout:i32,layout:PairI32->layout:PairI32", "direct,split->split", "none", "aggregate_result", target, triple, &ctx), &ctx);
    table = direct.mir_direct_call_table_with_agreement(table, agreement("agreement:chain", "call:chain", "aggregate_result_chain", "mir.function.main", "mir.function.consume", "plan:chain", "abi:consume", "sig:consume:pair_to_triple", aggregate_result, hidden_result, "layout:PairI32->layout:TripleI64", "split->hidden_pointer", "hidden_pointer:0", "producer_result_to_consumer_argument", target, triple, &ctx), &ctx);

    mut validation := direct.mir_direct_call_agreement_table_validate(table, authority, call_table, &ctx);
    if validation.valid == 0 { fail(std.Concat("Phase 16.5 direct-call agreement rejected: ", validation.reason_code)); }
    mut request := direct.mir_serialize_direct_call_agreement_for_request(table, authority, call_table, &ctx);
    mut witness := mir_to_c.mir_direct_call_mir_to_c_witness(table, authority, call_table, &ctx);
    if os.WriteFile("/tmp/gust-phase16-direct-call-agreement.request", request) == 0 ||
       os.WriteFile("/tmp/gust-phase16-direct-call-agreement.mir-to-c.witness", witness) == 0
    { fail("Phase 16.5 could not write parity artifacts"); }
    os.LogStr("SUCCESS: Phase 16.5 direct-call agreement smoke passed");
}
