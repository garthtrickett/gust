import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_return_terminal := typechecker.env_new(ctx);
    env_return_terminal.current_prefix = "main__";
    mut scope_return_terminal := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_return_terminal, "main__ReturnTerminalPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_return_terminal, "main__ReturnTerminalPayload", "main__close_return_terminal_payload", ctx);

    mut span_return_terminal: token.Span;

    mut payload_return_terminal := typechecker.make_type_struct("main__ReturnTerminalPayload", "", ctx);
    mut resource_return_terminal := typechecker.make_type_resource(payload_return_terminal, ctx);
    mut resource_type_idx_return_terminal: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_return_terminal, resource_return_terminal);

    mut body_decl_return_terminal: ast.Statement[ctx];
    unsafe {
        body_decl_return_terminal.tag = 4; // VarDecl
        body_decl_return_terminal.VarDecl.name = "return_terminal_resource";
        body_decl_return_terminal.VarDecl.is_mut = 1;
        body_decl_return_terminal.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        body_decl_return_terminal.VarDecl.var_type = resource_type_idx_return_terminal;
        body_decl_return_terminal.VarDecl.span = span_return_terminal;
    }

    mut callee_close_return_terminal: ast.Expression[ctx];
    unsafe {
        callee_close_return_terminal.tag = 0; // Identifier
        callee_close_return_terminal.Identifier.name = "main__close_return_terminal_payload";
        callee_close_return_terminal.Identifier.span = span_return_terminal;
    }
    mut callee_close_idx_return_terminal: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(callee_close_idx_return_terminal, callee_close_return_terminal);

    mut arg_close_return_terminal: ast.Expression[ctx];
    unsafe {
        arg_close_return_terminal.tag = 0; // Identifier
        arg_close_return_terminal.Identifier.name = "return_terminal_resource";
        arg_close_return_terminal.Identifier.span = span_return_terminal;
    }

    mut args_close_return_terminal: std.Vector[ast.Expression[ctx], ctx] := std.VectorNew(ctx);
    args_close_return_terminal.Push(arg_close_return_terminal);
    mut args_close_idx_return_terminal: Index[std.Vector[ast.Expression[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(args_close_idx_return_terminal, args_close_return_terminal);

    mut call_close_return_terminal: ast.Expression[ctx];
    unsafe {
        call_close_return_terminal.tag = 12; // Call
        call_close_return_terminal.Call.function = callee_close_idx_return_terminal;
        call_close_return_terminal.Call.arguments = args_close_idx_return_terminal;
        call_close_return_terminal.Call.span = span_return_terminal;
    }
    mut call_close_idx_return_terminal: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(call_close_idx_return_terminal, call_close_return_terminal);

    mut body_close_stmt_return_terminal: ast.Statement[ctx];
    unsafe {
        body_close_stmt_return_terminal.tag = 13; // Expression
        body_close_stmt_return_terminal.Expression.expr = call_close_idx_return_terminal;
        body_close_stmt_return_terminal.Expression.span = span_return_terminal;
    }

    mut body_return_stmt_terminal: ast.Statement[ctx];
    unsafe {
        body_return_stmt_terminal.tag = 12; // Return
        body_return_stmt_terminal.Return.expr = empty[Index[ast.Expression[ctx], ctx]];
        body_return_stmt_terminal.Return.span = span_return_terminal;
    }

    mut body_statements_return_terminal: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
    body_statements_return_terminal.Push(body_decl_return_terminal);
    body_statements_return_terminal.Push(body_close_stmt_return_terminal);
    body_statements_return_terminal.Push(body_return_stmt_terminal);
    mut body_statements_idx_return_terminal: Index[std.Vector[ast.Statement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_statements_idx_return_terminal, body_statements_return_terminal);

    mut body_return_terminal: ast.BlockStatement[ctx];
    body_return_terminal.statements = body_statements_idx_return_terminal;
    body_return_terminal.span = span_return_terminal;
    mut body_idx_return_terminal: Index[ast.BlockStatement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_idx_return_terminal, body_return_terminal);

    mut params_return_terminal: std.Vector[ast.Parameter[ctx], ctx] := std.VectorNew(ctx);
    mut params_idx_return_terminal: Index[std.Vector[ast.Parameter[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(params_idx_return_terminal, params_return_terminal);

    mut return_type_return_terminal: ast.Type[ctx];
    unsafe {
        return_type_return_terminal.tag = 3; // Void
    }
    mut return_type_idx_return_terminal: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(return_type_idx_return_terminal, return_type_return_terminal);

    mut function_stmt_return_terminal: ast.Statement[ctx];
    unsafe {
        function_stmt_return_terminal.tag = 3; // FunctionDecl
        function_stmt_return_terminal.FunctionDecl.name = "resource_return_terminal";
        function_stmt_return_terminal.FunctionDecl.is_unsafe = 0;
        function_stmt_return_terminal.FunctionDecl.is_extern = 0;
        function_stmt_return_terminal.FunctionDecl.extern_symbol_name = "";
        function_stmt_return_terminal.FunctionDecl.extern_abi = "C";
        function_stmt_return_terminal.FunctionDecl.requires_unsafe_call = 0;
        function_stmt_return_terminal.FunctionDecl.requires_layout_metadata = 0;
        function_stmt_return_terminal.FunctionDecl.requires_sandbox_arena = 0;
        function_stmt_return_terminal.FunctionDecl.params = params_idx_return_terminal;
        function_stmt_return_terminal.FunctionDecl.return_type = return_type_idx_return_terminal;
        function_stmt_return_terminal.FunctionDecl.body = body_idx_return_terminal;
        function_stmt_return_terminal.FunctionDecl.span = span_return_terminal;
    }
    mut function_stmt_idx_return_terminal: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(function_stmt_idx_return_terminal, function_stmt_return_terminal);

    typechecker.check_statement(function_stmt_idx_return_terminal, &env_return_terminal, scope_return_terminal, ctx);

    mut return_terminal_missing_cleanup_count := 0;
    mut error_idx_return_terminal := 0;
    while error_idx_return_terminal < len(env_return_terminal.errors) {
        mut msg_return_terminal := env_return_terminal.errors[error_idx_return_terminal].message;
        if std.str_find(msg_return_terminal, "LinearResourceMissingCleanup") != 0 - 1 {
            if std.str_find(msg_return_terminal, "return_terminal_resource") != 0 - 1 {
                return_terminal_missing_cleanup_count = return_terminal_missing_cleanup_count + 1;
            }
        }
        error_idx_return_terminal = error_idx_return_terminal + 1;
    }

    if return_terminal_missing_cleanup_count != 0 {
        os.LogStr("Error: return-path cleanup integration should not report closed terminal resources");
        if len(env_return_terminal.errors) > 0 {
            os.LogStr(env_return_terminal.errors[0].message);
        }
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource return cleanup terminal-state integration verified!");
}
