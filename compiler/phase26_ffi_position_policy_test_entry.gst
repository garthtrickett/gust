import "ast.gst" as ast;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    mut env := typechecker.env_new(ctx);
    mut str_type := typechecker.make_type_str();
    mut void_type: ast.Type[ctx];
    unsafe { void_type.tag = 3; }
    mut param: ast.Parameter[ctx];
    param.name = "value";
    param.param_type = str_type;
    param.ffi_policy = "borrow_read_call";
    mut params: std.Vector[ast.Parameter[ctx], ctx] := std.VectorNew(ctx);
    params.Push(param);
    mut params_idx: Index[std.Vector[ast.Parameter[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(params_idx, params);
    mut decl: ast.Statement[ctx];
    unsafe {
        decl.tag = 3;
        decl.FunctionDecl.is_extern = 1;
        decl.FunctionDecl.params = params_idx;
    }
    mut sig: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig);
    sig.params = std.VectorNew(ctx);
    sig.params.Push(str_type);
    sig.return_type = void_type;
    if typechecker.env_validate_extern_ffi_positions(&env, decl, &sig, ctx) != 1 {
        os.LogStr("Error: annotated read borrow did not validate");
        os.Exit(1);
    }
    mut policies: std.Vector[str, ctx] := ctx[sig.ffi_param_policies];
    if len(env.errors) != 0 || sig.ffi_contract_verified != 1 ||
       std.str_eq(sig.ffi_return_policy, "value") == 0 ||
       len(policies) != 1 || std.str_eq(policies[0], "borrow_read_call") == 0 {
        os.LogStr("Error: per-position ownership metadata was not canonicalized");
        os.Exit(1);
    }
    mut scalar_type := typechecker.make_type_int();
    param.param_type = scalar_type;
    param.ffi_policy = "";
    unsafe { params[0] = param; }
    ctx.Set(params_idx, params);
    unsafe { sig.params[0] = scalar_type; }
    if typechecker.env_validate_extern_ffi_positions(&env, decl, &sig, ctx) != 1 {
        os.LogStr("Error: scalar external position did not validate");
        os.Exit(1);
    }
    mut scalar_policies: std.Vector[str, ctx] := ctx[sig.ffi_param_policies];
    if len(scalar_policies) != 1 || std.str_eq(scalar_policies[0], "value") == 0 {
        os.LogStr("Error: scalar external position did not receive value metadata");
        os.Exit(1);
    }
    mut raw_type := typechecker.make_type_pointer(scalar_type, ctx);
    param.param_type = raw_type;
    param.ffi_policy = "borrow_write_call";
    unsafe { params[0] = param; }
    ctx.Set(params_idx, params);
    unsafe { sig.params[0] = raw_type; }
    if typechecker.env_validate_extern_ffi_positions(&env, decl, &sig, ctx) != 1 {
        os.LogStr("Error: annotated raw-pointer write borrow did not validate");
        os.Exit(1);
    }
    mut write_policies: std.Vector[str, ctx] := ctx[sig.ffi_param_policies];
    if len(write_policies) != 1 ||
       std.str_eq(write_policies[0], "borrow_write_call") == 0 {
        os.LogStr("Error: raw-pointer write borrow metadata was not canonicalized");
        os.Exit(1);
    }
    os.LogStr("SUCCESS: FFI per-position ownership metadata verified");
}
