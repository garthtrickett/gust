import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut plain_sig: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&plain_sig);

    if typechecker.function_signature_requires_sandbox_arena(plain_sig) != 0 {
        os.LogStr("Error: ordinary signatures must not require sandbox arenas by default");
        os.Exit(1);
    }
    if typechecker.function_signature_requires_ffi_policy(plain_sig) != 0 {
        os.LogStr("Error: ordinary signatures must not require any FFI policy by default");
        os.Exit(1);
    }
    if typechecker.function_signature_requires_sandbox_policy(plain_sig) != 0 {
        os.LogStr("Error: ordinary signatures must not require sandbox policy by default");
        os.Exit(1);
    }

    mut extern_sig: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&extern_sig);
    extern_sig.is_extern = 1;
    extern_sig.requires_unsafe_call = 1;

    if typechecker.function_signature_requires_ffi_policy(extern_sig) != 1 {
        os.LogStr("Error: extern signatures must require FFI policy metadata");
        os.Exit(1);
    }
    if typechecker.function_signature_requires_sandbox_policy(extern_sig) != 0 {
        os.LogStr("Error: extern signatures must not imply sandbox policy unless explicitly marked");
        os.Exit(1);
    }

    mut sandbox_sig: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sandbox_sig);
    sandbox_sig.is_extern = 1;
    sandbox_sig.requires_unsafe_call = 1;
    sandbox_sig.requires_sandbox_arena = 1;

    if typechecker.function_signature_requires_sandbox_arena(sandbox_sig) != 1 {
        os.LogStr("Error: sandbox signatures must require sandbox arena metadata");
        os.Exit(1);
    }
    if typechecker.function_signature_requires_sandbox_policy(sandbox_sig) != 1 {
        os.LogStr("Error: sandbox signatures must require sandbox policy metadata");
        os.Exit(1);
    }
    if typechecker.function_signature_requires_ffi_policy(sandbox_sig) != 1 {
        os.LogStr("Error: sandbox signatures must require aggregate FFI policy metadata");
        os.Exit(1);
    }

    mut layout_sandbox_sig: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&layout_sandbox_sig);
    layout_sandbox_sig.requires_layout_metadata = 1;
    layout_sandbox_sig.requires_sandbox_arena = 1;

    if typechecker.function_signature_requires_ffi_policy(layout_sandbox_sig) != 1 {
        os.LogStr("Error: layout+sandbox signatures must require aggregate FFI policy metadata");
        os.Exit(1);
    }
    if typechecker.function_signature_requires_sandbox_policy(layout_sandbox_sig) != 1 {
        os.LogStr("Error: layout+sandbox signatures must preserve explicit sandbox policy metadata");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert sandbox FFI policy helpers verified!");
}