import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);

    mut ordinary_sig: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&ordinary_sig);
    if typechecker.function_signature_requires_layout_policy(ordinary_sig) != 0 {
        os.LogStr("Error: ordinary signatures must not require layout policy by default");
        os.Exit(1);
    }

    mut layout_sig: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&layout_sig);
    layout_sig.requires_layout_metadata = 1;
    if typechecker.function_signature_requires_layout_policy(layout_sig) != 1 {
        os.LogStr("Error: signatures with explicit layout metadata requirement must require layout policy");
        os.Exit(1);
    }
    if typechecker.function_signature_requires_ffi_policy(layout_sig) != 1 {
        os.LogStr("Error: signatures with explicit layout metadata requirement must require aggregate FFI policy");
        os.Exit(1);
    }

    typechecker.env_register_struct_layout_metadata(&env, "main__Plain", 0, 0, "", ctx);
    if typechecker.env_struct_has_explicit_ffi_layout(&env, "main__Plain", ctx) != 0 {
        os.LogStr("Error: plain structs must not report explicit FFI layout metadata");
        os.Exit(1);
    }
    if typechecker.env_struct_satisfies_c_ffi_layout(&env, "main__Plain", ctx) != 0 {
        os.LogStr("Error: plain structs must not satisfy C FFI layout metadata");
        os.Exit(1);
    }
    if typechecker.env_struct_missing_c_ffi_layout(&env, "main__Plain", ctx) != 1 {
        os.LogStr("Error: plain structs must report missing C FFI layout metadata");
        os.Exit(1);
    }

    typechecker.env_register_struct_layout_metadata(&env, "main__CLike", 1, 0, "C", ctx);
    if typechecker.env_struct_has_explicit_ffi_layout(&env, "main__CLike", ctx) != 1 {
        os.LogStr("Error: repr-C structs must report explicit FFI layout metadata");
        os.Exit(1);
    }
    if typechecker.env_struct_satisfies_c_ffi_layout(&env, "main__CLike", ctx) != 1 {
        os.LogStr("Error: repr-C structs must satisfy C FFI layout metadata");
        os.Exit(1);
    }
    if typechecker.env_struct_missing_c_ffi_layout(&env, "main__CLike", ctx) != 0 {
        os.LogStr("Error: repr-C structs must not report missing C FFI layout metadata");
        os.Exit(1);
    }

    typechecker.env_register_struct_layout_metadata(&env, "main__Packed", 0, 1, "", ctx);
    if typechecker.env_struct_has_explicit_ffi_layout(&env, "main__Packed", ctx) != 1 {
        os.LogStr("Error: packed structs must report explicit FFI layout metadata");
        os.Exit(1);
    }
    if typechecker.env_struct_satisfies_c_ffi_layout(&env, "main__Packed", ctx) != 0 {
        os.LogStr("Error: packed-only structs must not satisfy C FFI layout metadata");
        os.Exit(1);
    }
    if typechecker.env_struct_missing_c_ffi_layout(&env, "main__Packed", ctx) != 1 {
        os.LogStr("Error: packed-only structs must report missing C FFI layout metadata");
        os.Exit(1);
    }

    if typechecker.env_struct_has_explicit_ffi_layout(&env, "main__Missing", ctx) != 0 {
        os.LogStr("Error: missing structs must not report explicit FFI layout metadata");
        os.Exit(1);
    }
    if typechecker.env_struct_satisfies_c_ffi_layout(&env, "main__Missing", ctx) != 0 {
        os.LogStr("Error: missing structs must not satisfy C FFI layout metadata");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert layout-aware FFI validation helpers verified!");
}