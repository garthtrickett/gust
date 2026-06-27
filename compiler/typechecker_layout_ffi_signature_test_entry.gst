import "ast.gst" as ast;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_lffi_sig := typechecker.env_new(ctx);

    typechecker.env_register_struct_layout_metadata(&env_lffi_sig, "main__Plain", 0, 0, "", ctx);
    typechecker.env_register_struct_layout_metadata(&env_lffi_sig, "main__CLike", 1, 0, "C", ctx);
    typechecker.env_register_struct_layout_metadata(&env_lffi_sig, "main__Packed", 0, 1, "", ctx);

    mut void_t_lffi_sig: ast.Type[ctx];
    void_t_lffi_sig.tag = 3; // Void

    mut int_t_lffi_sig: ast.Type[ctx];
    int_t_lffi_sig.tag = 0; // Int

    mut plain_t_lffi_sig: ast.Type[ctx];
    plain_t_lffi_sig.tag = 8; // Struct
    plain_t_lffi_sig.Struct.struct_name = "main__Plain";
    plain_t_lffi_sig.Struct.brand = empty[Index[str, ctx]];

    mut c_t_lffi_sig: ast.Type[ctx];
    c_t_lffi_sig.tag = 8; // Struct
    c_t_lffi_sig.Struct.struct_name = "main__CLike";
    c_t_lffi_sig.Struct.brand = empty[Index[str, ctx]];

    mut packed_t_lffi_sig: ast.Type[ctx];
    packed_t_lffi_sig.tag = 8; // Struct
    packed_t_lffi_sig.Struct.struct_name = "main__Packed";
    packed_t_lffi_sig.Struct.brand = empty[Index[str, ctx]];

    if typechecker.env_type_requires_explicit_c_ffi_layout(&env_lffi_sig, int_t_lffi_sig, ctx) != 0 {
        os.LogStr("Error: primitive int must not require explicit C FFI layout");
        os.Exit(1);
    }
    if typechecker.env_type_requires_explicit_c_ffi_layout(&env_lffi_sig, plain_t_lffi_sig, ctx) != 1 {
        os.LogStr("Error: struct values must require explicit C FFI layout when layout policy is active");
        os.Exit(1);
    }
    if typechecker.env_type_satisfies_c_ffi_layout(&env_lffi_sig, c_t_lffi_sig, ctx) != 1 {
        os.LogStr("Error: repr-C struct type must satisfy C FFI layout");
        os.Exit(1);
    }
    if typechecker.env_type_missing_c_ffi_layout(&env_lffi_sig, plain_t_lffi_sig, ctx) != 1 {
        os.LogStr("Error: unannotated struct type must report missing C FFI layout");
        os.Exit(1);
    }
    if typechecker.env_type_missing_c_ffi_layout(&env_lffi_sig, packed_t_lffi_sig, ctx) != 1 {
        os.LogStr("Error: packed-only struct type must report missing C FFI layout");
        os.Exit(1);
    }

    mut sig_policy_off_lffi: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig_policy_off_lffi);
    sig_policy_off_lffi.param_names = std.VectorNew(ctx);
    sig_policy_off_lffi.params = std.VectorNew(ctx);
    sig_policy_off_lffi.params.Push(plain_t_lffi_sig);
    sig_policy_off_lffi.return_type = void_t_lffi_sig;
    if typechecker.function_signature_missing_c_ffi_layout(&env_lffi_sig, sig_policy_off_lffi, ctx) != 0 {
        os.LogStr("Error: signatures without layout policy must not report missing layout");
        os.Exit(1);
    }

    mut sig_int_lffi: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig_int_lffi);
    sig_int_lffi.requires_layout_metadata = 1;
    sig_int_lffi.param_names = std.VectorNew(ctx);
    sig_int_lffi.params = std.VectorNew(ctx);
    sig_int_lffi.params.Push(int_t_lffi_sig);
    sig_int_lffi.return_type = void_t_lffi_sig;
    if typechecker.function_signature_missing_c_ffi_layout(&env_lffi_sig, sig_int_lffi, ctx) != 0 {
        os.LogStr("Error: primitive-only layout-policy signatures must not report missing C FFI layout");
        os.Exit(1);
    }

    mut sig_plain_lffi: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig_plain_lffi);
    sig_plain_lffi.requires_layout_metadata = 1;
    sig_plain_lffi.param_names = std.VectorNew(ctx);
    sig_plain_lffi.params = std.VectorNew(ctx);
    sig_plain_lffi.params.Push(plain_t_lffi_sig);
    sig_plain_lffi.return_type = void_t_lffi_sig;
    if typechecker.function_signature_missing_c_ffi_layout(&env_lffi_sig, sig_plain_lffi, ctx) != 1 {
        os.LogStr("Error: layout-policy signatures with unannotated struct params must report missing C FFI layout");
        os.Exit(1);
    }

    mut sig_c_param_lffi: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig_c_param_lffi);
    sig_c_param_lffi.requires_layout_metadata = 1;
    sig_c_param_lffi.param_names = std.VectorNew(ctx);
    sig_c_param_lffi.params = std.VectorNew(ctx);
    sig_c_param_lffi.params.Push(c_t_lffi_sig);
    sig_c_param_lffi.return_type = void_t_lffi_sig;
    if typechecker.function_signature_missing_c_ffi_layout(&env_lffi_sig, sig_c_param_lffi, ctx) != 0 {
        os.LogStr("Error: layout-policy signatures with repr-C struct params must not report missing C FFI layout");
        os.Exit(1);
    }

    mut sig_c_return_lffi: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig_c_return_lffi);
    sig_c_return_lffi.requires_layout_metadata = 1;
    sig_c_return_lffi.param_names = std.VectorNew(ctx);
    sig_c_return_lffi.params = std.VectorNew(ctx);
    sig_c_return_lffi.return_type = c_t_lffi_sig;
    if typechecker.function_signature_missing_c_ffi_layout(&env_lffi_sig, sig_c_return_lffi, ctx) != 0 {
        os.LogStr("Error: layout-policy signatures with repr-C struct returns must not report missing C FFI layout");
        os.Exit(1);
    }

    mut sig_packed_return_lffi: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig_packed_return_lffi);
    sig_packed_return_lffi.requires_layout_metadata = 1;
    sig_packed_return_lffi.param_names = std.VectorNew(ctx);
    sig_packed_return_lffi.params = std.VectorNew(ctx);
    sig_packed_return_lffi.return_type = packed_t_lffi_sig;
    if typechecker.function_signature_missing_c_ffi_layout(&env_lffi_sig, sig_packed_return_lffi, ctx) != 1 {
        os.LogStr("Error: layout-policy signatures with packed-only struct returns must report missing C FFI layout");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert signature-level C FFI layout helpers verified!");
}