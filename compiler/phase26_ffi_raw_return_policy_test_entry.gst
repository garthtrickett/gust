import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut env := typechecker.env_new(ctx);
    mut sig: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig);
    sig.is_extern = 1;
    sig.ffi_contract_verified = 1;
    sig.ffi_return_policy = "raw_untrusted";
    sig.return_type = typechecker.make_type_pointer(typechecker.make_type_int(), ctx);
    typechecker.env_register_function(&env, "tiny_host_raw_untrusted_int", sig, ctx);
    guard recorded := env.function_return_provenance.Get("tiny_host_raw_untrusted_int") else {
        os.LogStr("Error: extern raw return provenance was not registered");
        os.Exit(1);
        return;
    };
    if typechecker.step51g_expression_provenance_is_raw_derived(recorded) == 0 ||
       typechecker.expression_provenance_allows_safe_branding(recorded) != 0 {
        os.LogStr("Error: extern raw return was not recorded as unbrandable raw-derived provenance");
        os.Exit(1);
    }
    os.LogStr("SUCCESS: unowned extern raw return remains raw-derived and unbrandable");
}
