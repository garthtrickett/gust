import "mir_function_abi_authority.gst" as abi;
import "mir_abi_composition.gst" as composition;
import "mir_abi_composition_mir_to_c.gst" as composition_c;
func fail(message: str) { os.LogStr(message); os.Exit(1); }
func main() {
    mut ctx := os.Arena.New(); defer ctx.Free(); os.SetThreadScratch(ctx);
    mut target := "target:x86_64-unknown-linux-gnu"; mut triple := "x86_64-unknown-linux-gnu";
    mut table := abi.mir_function_abi_make_empty_table(target, triple, &ctx);
    mut function: abi.MirFunctionAbiIdentity[ctx]; function.abi_id = std.Clone(ctx, "abi:phase16:composition"); function.function_id = std.Clone(ctx, "mir.function.phase16.composition"); function.signature_id = std.Clone(ctx, "signature:phase16:composition"); function.calling_convention = std.Clone(ctx, "gust_canonical_v1"); function.target_id = std.Clone(ctx, target); function.target_triple = std.Clone(ctx, triple); function.parameter_placement_ids = abi.mir_abi_empty_str_vector(&ctx); function.result_placement_ids = abi.mir_abi_empty_str_vector(&ctx); table = abi.mir_function_abi_table_with_function(table, function, &ctx);
    mut plan := composition.mir_abi_composition_make_plan(&ctx); mut validation := composition.mir_abi_composition_validate(plan, table, &ctx); if validation.valid == 0 { fail(std.Concat("Phase 16.13 ABI composition rejected: ", validation.reason_code)); }
    mut request := composition.mir_abi_composition_append_to_request("", plan, table, &ctx); mut witness := composition_c.mir_abi_composition_mir_to_c_witness(plan, table, &ctx);
    if std.str_find(witness, "covered_entries=12") == 0 - 1 || std.str_find(witness, "mir_to_c_cranelift_witness_identity=1") == 0 - 1 { fail("Phase 16.13 ABI composition witness drifted"); }
    if os.WriteFile("/tmp/gust-phase16-abi-composition.request", request) == 0 || os.WriteFile("/tmp/gust-phase16-abi-composition.mir-to-c.witness", witness) == 0 { fail("Phase 16.13 ABI composition artifacts could not be written"); }
    os.LogStr("SUCCESS: Phase 16.13 ABI composition parity smoke passed");
}
