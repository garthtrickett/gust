import "ast.gst" as ast;
import "typechecker.gst" as typechecker;

func check_case(origin: int, unsafe_callee: int, ctx: &Arena) {
    mut reference_type := typechecker.make_type_reference(typechecker.make_type_int(), "", ctx);
    mut signature: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&signature);
    signature.is_unsafe = unsafe_callee;
    mut provenance := typechecker.expression_provenance_unknown(reference_type, ctx);
    if origin == 1 { provenance = typechecker.expression_provenance_raw_derived(reference_type, ctx); }
    if origin == 2 { provenance = typechecker.expression_provenance_sandbox_derived(reference_type, ctx); }
    if origin == 3 { provenance = typechecker.expression_provenance_safe_arena(reference_type, ctx); }
    mut observed := typechecker.phase26_safe_call_unbranded_reference_arg_escapes(signature, reference_type, provenance, ctx);
    if (origin == 1 || origin == 2) && unsafe_callee == 0 {
        if observed != 1 { os.LogStr("Error: derived Reference was admitted to safe callee"); os.Exit(1); }
    } else {
        if observed != 0 { os.LogStr("Error: unaffected Reference call changed"); os.Exit(1); }
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    check_case(0, 0, ctx);
    check_case(1, 0, ctx);
    check_case(2, 0, ctx);
    check_case(3, 0, ctx);
    check_case(1, 1, ctx);
    check_case(2, 1, ctx);
    os.LogStr("SUCCESS: safe-call Reference provenance boundary verified");
}
