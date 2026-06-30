import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_return_dedup := typechecker.env_new(ctx);
    env_return_dedup.current_prefix = "main__";
    mut scope_return_dedup := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_return_dedup, "main__ReturnDedupPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_return_dedup, "main__ReturnDedupPayload", "main__close_return_dedup_payload", ctx);

    mut span_return_dedup: token.Span;

    mut payload_return_dedup := typechecker.make_type_struct("main__ReturnDedupPayload", "", ctx);
    mut resource_return_dedup := typechecker.make_type_resource(payload_return_dedup, ctx);
    mut resource_type_idx_return_dedup: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_return_dedup, resource_return_dedup);

    mut body_decl_return_dedup: ast.Statement[ctx];
    unsafe {
        body_decl_return_dedup.tag = 4; // VarDecl
        body_decl_return_dedup.VarDecl.name = "return_dedup_resource";
        body_decl_return_dedup.VarDecl.is_mut = 1;
        body_decl_return_dedup.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        body_decl_return_dedup.VarDecl.var_type = resource_type_idx_return_dedup;
        body_decl_return_dedup.VarDecl.span = span_return_dedup;
    }

    mut body_return_stmt_dedup: ast.Statement[ctx];
    unsafe {
        body_return_stmt_dedup.tag = 12; // Return
        body_return_stmt_dedup.Return.expr = empty[Index[ast.Expression[ctx], ctx]];
        body_return_stmt_dedup.Return.span = span_return_dedup;
    }

    mut body_statements_return_dedup: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
    body_statements_return_dedup.Push(body_decl_return_dedup);
    body_statements_return_dedup.Push(body_return_stmt_dedup);
    mut body_statements_idx_return_dedup: Index[std.Vector[ast.Statement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_statements_idx_return_dedup, body_statements_return_dedup);

    mut body_return_dedup: ast.BlockStatement[ctx];
    body_return_dedup.statements = body_statements_idx_return_dedup;
    body_return_dedup.span = span_return_dedup;
    mut body_idx_return_dedup: Index[ast.BlockStatement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_idx_return_dedup, body_return_dedup);

    mut params_return_dedup: std.Vector[ast.Parameter[ctx], ctx] := std.VectorNew(ctx);
    mut params_idx_return_dedup: Index[std.Vector[ast.Parameter[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(params_idx_return_dedup, params_return_dedup);

    mut return_type_return_dedup: ast.Type[ctx];
    unsafe {
        return_type_return_dedup.tag = 3; // Void
    }
    mut return_type_idx_return_dedup: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(return_type_idx_return_dedup, return_type_return_dedup);

    mut function_stmt_return_dedup: ast.Statement[ctx];
    unsafe {
        function_stmt_return_dedup.tag = 3; // FunctionDecl
        function_stmt_return_dedup.FunctionDecl.name = "resource_return_dedup";
        function_stmt_return_dedup.FunctionDecl.is_unsafe = 0;
        function_stmt_return_dedup.FunctionDecl.is_extern = 0;
        function_stmt_return_dedup.FunctionDecl.extern_symbol_name = "";
        function_stmt_return_dedup.FunctionDecl.extern_abi = "C";
        function_stmt_return_dedup.FunctionDecl.requires_unsafe_call = 0;
        function_stmt_return_dedup.FunctionDecl.requires_layout_metadata = 0;
        function_stmt_return_dedup.FunctionDecl.requires_sandbox_arena = 0;
        function_stmt_return_dedup.FunctionDecl.params = params_idx_return_dedup;
        function_stmt_return_dedup.FunctionDecl.return_type = return_type_idx_return_dedup;
        function_stmt_return_dedup.FunctionDecl.body = body_idx_return_dedup;
        function_stmt_return_dedup.FunctionDecl.span = span_return_dedup;
    }
    mut function_stmt_idx_return_dedup: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(function_stmt_idx_return_dedup, function_stmt_return_dedup);

    typechecker.check_statement(function_stmt_idx_return_dedup, &env_return_dedup, scope_return_dedup, ctx);

    mut return_dedup_missing_cleanup_count := 0;
    mut error_idx_return_dedup := 0;
    while error_idx_return_dedup < len(env_return_dedup.errors) {
        mut msg_return_dedup := env_return_dedup.errors[error_idx_return_dedup].message;
        if std.str_find(msg_return_dedup, "LinearResourceMissingCleanup") != 0 - 1 {
            if std.str_find(msg_return_dedup, "return_dedup_resource") != 0 - 1 {
                return_dedup_missing_cleanup_count = return_dedup_missing_cleanup_count + 1;
            }
        }
        error_idx_return_dedup = error_idx_return_dedup + 1;
    }

    if return_dedup_missing_cleanup_count != 1 {
        os.LogStr("Error: return-path plus function-exit cleanup integration should emit exactly one pending cleanup diagnostic for the same resource");
        if len(env_return_dedup.errors) > 0 {
            os.LogStr(env_return_dedup.errors[0].message);
        }
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource return cleanup dedup integration verified!");
}