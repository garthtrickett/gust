import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_function_moved_terminal := typechecker.env_new(ctx);
    env_function_moved_terminal.current_prefix = "main__";
    mut scope_function_moved_terminal := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_function_moved_terminal, "main__FunctionMovedPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_function_moved_terminal, "main__FunctionMovedPayload", "main__close_function_moved_payload", ctx);

    mut span_function_moved_terminal: token.Span;

    mut payload_function_moved_terminal := typechecker.make_type_struct("main__FunctionMovedPayload", "", ctx);
    mut resource_function_moved_terminal := typechecker.make_type_resource(payload_function_moved_terminal, ctx);
    mut resource_type_idx_function_moved_terminal: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_function_moved_terminal, resource_function_moved_terminal);

    mut destructor_sig_function_moved_terminal: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&destructor_sig_function_moved_terminal);
    destructor_sig_function_moved_terminal.param_names = std.VectorNew(ctx);
    destructor_sig_function_moved_terminal.param_names.Push("resource");
    destructor_sig_function_moved_terminal.params = std.VectorNew(ctx);
    destructor_sig_function_moved_terminal.params.Push(resource_function_moved_terminal);
    mut destructor_void_function_moved_terminal: ast.Type[ctx];
    unsafe {
        destructor_void_function_moved_terminal.tag = 3; // Void
    }
    destructor_sig_function_moved_terminal.return_type = destructor_void_function_moved_terminal;
    destructor_sig_function_moved_terminal.return_origins = typechecker.set_init(ctx);
    destructor_sig_function_moved_terminal.is_unsafe = 0;
    env_function_moved_terminal.function_registry.Insert("main__close_function_moved_payload", destructor_sig_function_moved_terminal);

    mut source_decl_function_moved_terminal: ast.Statement[ctx];
    unsafe {
        source_decl_function_moved_terminal.tag = 4; // VarDecl
        source_decl_function_moved_terminal.VarDecl.name = "function_moved_source_resource";
        source_decl_function_moved_terminal.VarDecl.is_mut = 1;
        source_decl_function_moved_terminal.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        source_decl_function_moved_terminal.VarDecl.var_type = resource_type_idx_function_moved_terminal;
        source_decl_function_moved_terminal.VarDecl.span = span_function_moved_terminal;
    }

    mut target_decl_function_moved_terminal: ast.Statement[ctx];
    unsafe {
        target_decl_function_moved_terminal.tag = 4; // VarDecl
        target_decl_function_moved_terminal.VarDecl.name = "function_moved_target_resource";
        target_decl_function_moved_terminal.VarDecl.is_mut = 1;
        target_decl_function_moved_terminal.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        target_decl_function_moved_terminal.VarDecl.var_type = resource_type_idx_function_moved_terminal;
        target_decl_function_moved_terminal.VarDecl.span = span_function_moved_terminal;
    }

    mut assign_left_function_moved_terminal: ast.Expression[ctx];
    unsafe {
        assign_left_function_moved_terminal.tag = 0; // Identifier
        assign_left_function_moved_terminal.Identifier.name = "function_moved_target_resource";
        assign_left_function_moved_terminal.Identifier.span = span_function_moved_terminal;
    }
    mut assign_left_idx_function_moved_terminal: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(assign_left_idx_function_moved_terminal, assign_left_function_moved_terminal);

    mut assign_value_function_moved_terminal: ast.Expression[ctx];
    unsafe {
        assign_value_function_moved_terminal.tag = 0; // Identifier
        assign_value_function_moved_terminal.Identifier.name = "function_moved_source_resource";
        assign_value_function_moved_terminal.Identifier.span = span_function_moved_terminal;
    }
    mut assign_value_idx_function_moved_terminal: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(assign_value_idx_function_moved_terminal, assign_value_function_moved_terminal);

    mut assign_stmt_function_moved_terminal: ast.Statement[ctx];
    unsafe {
        assign_stmt_function_moved_terminal.tag = 5; // Assignment
        assign_stmt_function_moved_terminal.Assignment.left = assign_left_idx_function_moved_terminal;
        assign_stmt_function_moved_terminal.Assignment.value = assign_value_idx_function_moved_terminal;
        assign_stmt_function_moved_terminal.Assignment.span = span_function_moved_terminal;
    }

    mut callee_close_function_moved_terminal: ast.Expression[ctx];
    unsafe {
        callee_close_function_moved_terminal.tag = 0; // Identifier
        callee_close_function_moved_terminal.Identifier.name = "main__close_function_moved_payload";
        callee_close_function_moved_terminal.Identifier.span = span_function_moved_terminal;
    }
    mut callee_close_idx_function_moved_terminal: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(callee_close_idx_function_moved_terminal, callee_close_function_moved_terminal);

    mut arg_close_function_moved_terminal: ast.Expression[ctx];
    unsafe {
        arg_close_function_moved_terminal.tag = 0; // Identifier
        arg_close_function_moved_terminal.Identifier.name = "function_moved_target_resource";
        arg_close_function_moved_terminal.Identifier.span = span_function_moved_terminal;
    }

    mut args_close_function_moved_terminal: std.Vector[ast.Expression[ctx], ctx] := std.VectorNew(ctx);
    args_close_function_moved_terminal.Push(arg_close_function_moved_terminal);
    mut args_close_idx_function_moved_terminal: Index[std.Vector[ast.Expression[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(args_close_idx_function_moved_terminal, args_close_function_moved_terminal);

    mut call_close_function_moved_terminal: ast.Expression[ctx];
    unsafe {
        call_close_function_moved_terminal.tag = 12; // Call
        call_close_function_moved_terminal.Call.function = callee_close_idx_function_moved_terminal;
        call_close_function_moved_terminal.Call.arguments = args_close_idx_function_moved_terminal;
        call_close_function_moved_terminal.Call.span = span_function_moved_terminal;
    }
    mut call_close_idx_function_moved_terminal: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(call_close_idx_function_moved_terminal, call_close_function_moved_terminal);

    mut close_stmt_function_moved_terminal: ast.Statement[ctx];
    unsafe {
        close_stmt_function_moved_terminal.tag = 13; // Expression
        close_stmt_function_moved_terminal.Expression.expr = call_close_idx_function_moved_terminal;
        close_stmt_function_moved_terminal.Expression.span = span_function_moved_terminal;
    }

    mut body_statements_function_moved_terminal: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
    body_statements_function_moved_terminal.Push(source_decl_function_moved_terminal);
    body_statements_function_moved_terminal.Push(target_decl_function_moved_terminal);
    body_statements_function_moved_terminal.Push(assign_stmt_function_moved_terminal);
    body_statements_function_moved_terminal.Push(close_stmt_function_moved_terminal);
    mut body_statements_idx_function_moved_terminal: Index[std.Vector[ast.Statement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_statements_idx_function_moved_terminal, body_statements_function_moved_terminal);

    mut body_function_moved_terminal: ast.BlockStatement[ctx];
    body_function_moved_terminal.statements = body_statements_idx_function_moved_terminal;
    body_function_moved_terminal.span = span_function_moved_terminal;
    mut body_idx_function_moved_terminal: Index[ast.BlockStatement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_idx_function_moved_terminal, body_function_moved_terminal);

    mut params_function_moved_terminal: std.Vector[ast.Parameter[ctx], ctx] := std.VectorNew(ctx);
    mut params_idx_function_moved_terminal: Index[std.Vector[ast.Parameter[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(params_idx_function_moved_terminal, params_function_moved_terminal);

    mut return_type_function_moved_terminal: ast.Type[ctx];
    unsafe {
        return_type_function_moved_terminal.tag = 3; // Void
    }
    mut return_type_idx_function_moved_terminal: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(return_type_idx_function_moved_terminal, return_type_function_moved_terminal);

    mut function_stmt_function_moved_terminal: ast.Statement[ctx];
    unsafe {
        function_stmt_function_moved_terminal.tag = 3; // FunctionDecl
        function_stmt_function_moved_terminal.FunctionDecl.name = "resource_function_moved_terminal";
        function_stmt_function_moved_terminal.FunctionDecl.is_unsafe = 0;
        function_stmt_function_moved_terminal.FunctionDecl.is_extern = 0;
        function_stmt_function_moved_terminal.FunctionDecl.extern_symbol_name = "";
        function_stmt_function_moved_terminal.FunctionDecl.extern_abi = "C";
        function_stmt_function_moved_terminal.FunctionDecl.requires_unsafe_call = 0;
        function_stmt_function_moved_terminal.FunctionDecl.requires_layout_metadata = 0;
        function_stmt_function_moved_terminal.FunctionDecl.requires_sandbox_arena = 0;
        function_stmt_function_moved_terminal.FunctionDecl.params = params_idx_function_moved_terminal;
        function_stmt_function_moved_terminal.FunctionDecl.return_type = return_type_idx_function_moved_terminal;
        function_stmt_function_moved_terminal.FunctionDecl.body = body_idx_function_moved_terminal;
        function_stmt_function_moved_terminal.FunctionDecl.span = span_function_moved_terminal;
    }
    mut function_stmt_idx_function_moved_terminal: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(function_stmt_idx_function_moved_terminal, function_stmt_function_moved_terminal);

    typechecker.check_statement(function_stmt_idx_function_moved_terminal, &env_function_moved_terminal, scope_function_moved_terminal, ctx);

    mut function_moved_missing_cleanup_count := 0;
    mut error_idx_function_moved_terminal := 0;
    while error_idx_function_moved_terminal < len(env_function_moved_terminal.errors) {
        mut msg_function_moved_terminal := env_function_moved_terminal.errors[error_idx_function_moved_terminal].message;
        if std.str_find(msg_function_moved_terminal, "LinearResourceMissingCleanup") != 0 - 1 {
            if std.str_find(msg_function_moved_terminal, "function_moved_source_resource") != 0 - 1 {
                function_moved_missing_cleanup_count = function_moved_missing_cleanup_count + 1;
            }
            if std.str_find(msg_function_moved_terminal, "function_moved_target_resource") != 0 - 1 {
                function_moved_missing_cleanup_count = function_moved_missing_cleanup_count + 1;
            }
        }
        error_idx_function_moved_terminal = error_idx_function_moved_terminal + 1;
    }

    if function_moved_missing_cleanup_count != 0 {
        os.LogStr("Error: function-exit cleanup integration should not report moved/closed terminal resources");
        if len(env_function_moved_terminal.errors) > 0 {
            os.LogStr(env_function_moved_terminal.errors[0].message);
        }
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource function-exit moved terminal-state integration verified!");
}