import "ast.gst" as ast;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);
    env.current_prefix = "main__";
    
    // Set import alias: "lib" -> "lib__"
    env.imports.Insert(std.Clone(ctx, "lib"), std.Clone(ctx, "lib__"));

    // Register a dummy struct "lib__Helper"
    mut layout: typechecker.StructLayout[ctx];
    layout.brand = empty[Index[str, ctx]];
    layout.fields = std.HashMapNew(ctx);
    typechecker.env_register_struct(&env, "lib__Helper", layout, ctx);

    // Register a dummy function "lib__add"
    mut sig: typechecker.FunctionSignature[ctx];
    sig.param_names = std.VectorNew(ctx);
    sig.params = std.VectorNew(ctx);
    sig.is_unsafe = 0;
    unsafe { 
        sig.return_type.tag = 0; // Int
    }
    typechecker.env_register_function(&env, "lib__add", sig, ctx);

    // Resolve lookups
    mut res1 := typechecker.env_resolve_namespaced_ident(&env, "lib.Helper", ctx);
    os.LogStr(res1);

    mut res2 := typechecker.env_resolve_namespaced_ident(&env, "lib.add", ctx);
    os.LogStr(res2);

    mut res3 := typechecker.env_resolve_namespaced_ident(&env, "local_var", ctx);
    os.LogStr(res3);

    mut res4 := typechecker.env_resolve_namespaced_ident(&env, "int", ctx);
    os.LogStr(res4);

    mut res5 := typechecker.env_resolve_namespaced_ident(&env, "LookupResult_lib.Helper", ctx);
    os.LogStr(res5);

    mut res6 := typechecker.env_resolve_namespaced_ident(&env, "std_Vector_lib_Helper_ctx", ctx);
    os.LogStr(res6);
}
