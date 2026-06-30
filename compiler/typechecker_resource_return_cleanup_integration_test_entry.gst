import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_return_cleanup := typechecker.env_new(ctx);
    env_return_cleanup.current_prefix = "main__";
    mut scope_return_cleanup := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_return_cleanup, "main__ReturnCleanupPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_return_cleanup, "main__ReturnCleanupPayload", "main__close_return_cleanup_payload", ctx);

    mut span_return_cleanup: token.Span;

    mut payload_return_cleanup := typechecker.make_type_struct("main__ReturnCleanupPayload", "", ctx);
    mut resource_return_cleanup := typechecker.make_type_resource(payload_return_cleanup, ctx);
    mut resource_type_idx_return_cleanup: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_return_cleanup, resource_return_cleanup);

    mut body_decl_return_cleanup: ast.Statement[ctx];
    unsafe {
        body_decl_return_cleanup.tag = 4; // VarDecl
        body_decl_return_cleanup.VarDecl.name = "return_cleanup_resource";
        body_decl_return_cleanup.VarDecl.is_mut = 1;
        body_decl_return_cleanup.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        body_decl_return_cleanup.VarDecl.var_type = resource_type_idx_return_cleanup;
        body_decl_return_cleanup.VarDecl.span = span_return_cleanup;
    }

    mut body_return_stmt_cleanup: ast.Statement[ctx];
    unsafe {
        body_return_stmt_cleanup.tag = 12; // Return
        body_return_stmt_cleanup.Return.expr = empty[Index[ast.Expression[ctx], ctx]];
        body_return_stmt_cleanup.Return.span = span_return_cleanup;
    }

    mut body_statements_return_cleanup: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
    body_statements_return_cleanup.Push(body_decl_return_cleanup);
    body_statements_return_cleanup.Push(body_return_stmt_cleanup);
    mut body_statements_idx_return_cleanup: Index[std.Vector[ast.Statement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_statements_idx_return_cleanup, body_statements_return_cleanup);

    mut body_return_cleanup: ast.BlockStatement[ctx];
    body_return_cleanup.statements = body_statements_idx_return_cleanup;
    body_return_cleanup.span = span_return_cleanup;
    mut body_idx_return_cleanup: Index[ast.BlockStatement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_idx_return_cleanup, body_return_cleanup);

    mut params_return_cleanup: std.Vector[ast.Parameter[ctx], ctx] := std.VectorNew(ctx);
    mut params_idx_return_cleanup: Index[std.Vector[ast.Parameter[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(params_idx_return_cleanup, params_return_cleanup);

    mut return_type_return_cleanup: ast.Type[ctx];
    unsafe {
        return_type_return_cleanup.tag = 3; // Void
    }
    mut return_type_idx_return_cleanup: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(return_type_idx_return_cleanup, return_type_return_cleanup);

    mut function_stmt_return_cleanup: ast.Statement[ctx];
    unsafe {
        function_stmt_return_cleanup.tag = 3; // FunctionDecl
        function_stmt_return_cleanup.FunctionDecl.name = "resource_return_cleanup";
        function_stmt_return_cleanup.FunctionDecl.is_unsafe = 0;
        function_stmt_return_cleanup.FunctionDecl.is_extern = 0;
        function_stmt_return_cleanup.FunctionDecl.extern_symbol_name = "";
        function_stmt_return_cleanup.FunctionDecl.extern_abi = "C";
        function_stmt_return_cleanup.FunctionDecl.requires_unsafe_call = 0;
        function_stmt_return_cleanup.FunctionDecl.requires_layout_metadata = 0;
        function_stmt_return_cleanup.FunctionDecl.requires_sandbox_arena = 0;
        function_stmt_return_cleanup.FunctionDecl.params = params_idx_return_cleanup;
        function_stmt_return_cleanup.FunctionDecl.return_type = return_type_idx_return_cleanup;
        function_stmt_return_cleanup.FunctionDecl.body = body_idx_return_cleanup;
        function_stmt_return_cleanup.FunctionDecl.span = span_return_cleanup;
    }
    mut function_stmt_idx_return_cleanup: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(function_stmt_idx_return_cleanup, function_stmt_return_cleanup);

    typechecker.check_statement(function_stmt_idx_return_cleanup, &env_return_cleanup, scope_return_cleanup, ctx);

    mut found_return_cleanup_error := 0;
    mut error_idx_return_cleanup := 0;
    while error_idx_return_cleanup < len(env_return_cleanup.errors) {
        mut msg_return_cleanup := env_return_cleanup.errors[error_idx_return_cleanup].message;
        if std.str_find(msg_return_cleanup, "LinearResourceMissingCleanup") != 0 - 1 {
            if std.str_find(msg_return_cleanup, "return_cleanup_resource") != 0 - 1 {
                found_return_cleanup_error = 1;
            }
        }
        error_idx_return_cleanup = error_idx_return_cleanup + 1;
    }

    if found_return_cleanup_error != 1 {
        os.LogStr("Error: return-path Resource cleanup integration did not emit the expected pending cleanup diagnostic");
        if len(env_return_cleanup.errors) > 0 {
            os.LogStr(env_return_cleanup.errors[0].message);
        }
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource return cleanup integration verified!");
}