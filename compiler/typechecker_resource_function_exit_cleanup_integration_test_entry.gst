import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_function_exit := typechecker.env_new(ctx);
    env_function_exit.current_prefix = "main__";
    mut scope_function_exit := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_function_exit, "main__FunctionExitPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_function_exit, "main__FunctionExitPayload", "main__close_function_exit_payload", ctx);

    mut span_function_exit: token.Span;

    mut payload_function_exit := typechecker.make_type_struct("main__FunctionExitPayload", "", ctx);
    mut resource_function_exit := typechecker.make_type_resource(payload_function_exit, ctx);
    mut resource_type_idx_function_exit: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_function_exit, resource_function_exit);

    mut body_decl_function_exit: ast.Statement[ctx];
    unsafe {
        body_decl_function_exit.tag = 4; // VarDecl
        body_decl_function_exit.VarDecl.name = "function_exit_resource";
        body_decl_function_exit.VarDecl.is_mut = 1;
        body_decl_function_exit.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        body_decl_function_exit.VarDecl.var_type = resource_type_idx_function_exit;
        body_decl_function_exit.VarDecl.span = span_function_exit;
    }

    mut body_statements_function_exit: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
    body_statements_function_exit.Push(body_decl_function_exit);
    mut body_statements_idx_function_exit: Index[std.Vector[ast.Statement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_statements_idx_function_exit, body_statements_function_exit);

    mut body_function_exit: ast.BlockStatement[ctx];
    body_function_exit.statements = body_statements_idx_function_exit;
    body_function_exit.span = span_function_exit;
    mut body_idx_function_exit: Index[ast.BlockStatement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_idx_function_exit, body_function_exit);

    mut params_function_exit: std.Vector[ast.Parameter[ctx], ctx] := std.VectorNew(ctx);
    mut params_idx_function_exit: Index[std.Vector[ast.Parameter[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(params_idx_function_exit, params_function_exit);

    mut return_type_function_exit: ast.Type[ctx];
    return_type_function_exit.tag = 3; // Void
    mut return_type_idx_function_exit: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(return_type_idx_function_exit, return_type_function_exit);

    mut function_stmt_function_exit: ast.Statement[ctx];
    unsafe {
        function_stmt_function_exit.tag = 3; // FunctionDecl
        function_stmt_function_exit.FunctionDecl.name = "resource_function_exit";
        function_stmt_function_exit.FunctionDecl.is_unsafe = 0;
        function_stmt_function_exit.FunctionDecl.is_extern = 0;
        function_stmt_function_exit.FunctionDecl.extern_symbol_name = "";
        function_stmt_function_exit.FunctionDecl.extern_abi = "C";
        function_stmt_function_exit.FunctionDecl.requires_unsafe_call = 0;
        function_stmt_function_exit.FunctionDecl.requires_layout_metadata = 0;
        function_stmt_function_exit.FunctionDecl.requires_sandbox_arena = 0;
        function_stmt_function_exit.FunctionDecl.params = params_idx_function_exit;
        function_stmt_function_exit.FunctionDecl.return_type = return_type_idx_function_exit;
        function_stmt_function_exit.FunctionDecl.body = body_idx_function_exit;
        function_stmt_function_exit.FunctionDecl.span = span_function_exit;
    }
    mut function_stmt_idx_function_exit: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(function_stmt_idx_function_exit, function_stmt_function_exit);

    typechecker.check_statement(function_stmt_idx_function_exit, &env_function_exit, scope_function_exit, ctx);

    if len(env_function_exit.errors) != 1 {
        os.LogStr("Error: function-exit Resource cleanup integration should record exactly one error");
        os.Exit(1);
    }
    if std.str_find(env_function_exit.errors[0].message, "LinearResourceMissingCleanup") == 0 - 1 {
        os.LogStr("Error: function-exit Resource cleanup integration emitted wrong diagnostic");
        os.LogStr(env_function_exit.errors[0].message);
        os.Exit(1);
    }
    if std.str_find(env_function_exit.errors[0].message, "function_exit_resource") == 0 - 1 {
        os.LogStr("Error: function-exit Resource cleanup integration did not report the pending resource name");
        os.LogStr(env_function_exit.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource function-exit cleanup integration verified!");
}