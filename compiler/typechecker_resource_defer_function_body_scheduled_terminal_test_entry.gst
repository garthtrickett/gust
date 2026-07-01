import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span_function_body_scheduled: token.Span;
    mut payload_function_body_scheduled := typechecker.make_type_struct("main__DeferFunctionBodyPayload", "", ctx);
    mut resource_function_body_scheduled := typechecker.make_type_resource(payload_function_body_scheduled, ctx);
    mut resource_type_idx_function_body_scheduled: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_function_body_scheduled, resource_function_body_scheduled);

    mut return_type_function_body_scheduled: ast.Type[ctx];
    unsafe {
        return_type_function_body_scheduled.tag = 3; // Void
    }
    mut return_type_idx_function_body_scheduled: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(return_type_idx_function_body_scheduled, return_type_function_body_scheduled);

    mut env_return_body_scheduled := typechecker.env_new(ctx);
    env_return_body_scheduled.current_prefix = "main__";
    mut scope_return_body_scheduled := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct_linear_metadata(&env_return_body_scheduled, "main__DeferFunctionBodyPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_return_body_scheduled, "main__DeferFunctionBodyPayload", "close_defer_function_body_payload", ctx);

    mut decl_return_body_scheduled: ast.Statement[ctx];
    unsafe {
        decl_return_body_scheduled.tag = 4; // VarDecl
        decl_return_body_scheduled.VarDecl.name = "return_body_scheduled_resource";
        decl_return_body_scheduled.VarDecl.is_mut = 1;
        decl_return_body_scheduled.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        decl_return_body_scheduled.VarDecl.var_type = resource_type_idx_function_body_scheduled;
        decl_return_body_scheduled.VarDecl.span = span_function_body_scheduled;
    }

    mut lex_return_body_defer: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_return_body_defer, "defer close_defer_function_body_payload(return_body_scheduled_resource);");
    mut parser_return_body_defer: parser.Parser[ctx];
    parser.init_parser(&parser_return_body_defer, &lex_return_body_defer, ctx);
    mut defer_return_body_scheduled := parser.parse_statement(&parser_return_body_defer, ctx);

    mut return_stmt_return_body_scheduled: ast.Statement[ctx];
    unsafe {
        return_stmt_return_body_scheduled.tag = 12; // Return
        return_stmt_return_body_scheduled.Return.expr = empty[Index[ast.Expression[ctx], ctx]];
        return_stmt_return_body_scheduled.Return.span = span_function_body_scheduled;
    }

    mut body_statements_return_body_scheduled: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
    body_statements_return_body_scheduled.Push(decl_return_body_scheduled);
    body_statements_return_body_scheduled.Push(ctx[defer_return_body_scheduled]);
    body_statements_return_body_scheduled.Push(return_stmt_return_body_scheduled);
    mut body_statements_idx_return_body_scheduled: Index[std.Vector[ast.Statement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_statements_idx_return_body_scheduled, body_statements_return_body_scheduled);

    mut body_return_body_scheduled: ast.BlockStatement[ctx];
    body_return_body_scheduled.statements = body_statements_idx_return_body_scheduled;
    body_return_body_scheduled.span = span_function_body_scheduled;
    mut body_idx_return_body_scheduled: Index[ast.BlockStatement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_idx_return_body_scheduled, body_return_body_scheduled);

    mut params_return_body_scheduled: std.Vector[ast.Parameter[ctx], ctx] := std.VectorNew(ctx);
    mut params_idx_return_body_scheduled: Index[std.Vector[ast.Parameter[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(params_idx_return_body_scheduled, params_return_body_scheduled);

    mut function_stmt_return_body_scheduled: ast.Statement[ctx];
    unsafe {
        function_stmt_return_body_scheduled.tag = 3; // FunctionDecl
        function_stmt_return_body_scheduled.FunctionDecl.name = "defer_return_body_scheduled_resource";
        function_stmt_return_body_scheduled.FunctionDecl.is_unsafe = 0;
        function_stmt_return_body_scheduled.FunctionDecl.is_extern = 0;
        function_stmt_return_body_scheduled.FunctionDecl.extern_symbol_name = "";
        function_stmt_return_body_scheduled.FunctionDecl.extern_abi = "C";
        function_stmt_return_body_scheduled.FunctionDecl.requires_unsafe_call = 0;
        function_stmt_return_body_scheduled.FunctionDecl.requires_layout_metadata = 0;
        function_stmt_return_body_scheduled.FunctionDecl.requires_sandbox_arena = 0;
        function_stmt_return_body_scheduled.FunctionDecl.params = params_idx_return_body_scheduled;
        function_stmt_return_body_scheduled.FunctionDecl.return_type = return_type_idx_function_body_scheduled;
        function_stmt_return_body_scheduled.FunctionDecl.body = body_idx_return_body_scheduled;
        function_stmt_return_body_scheduled.FunctionDecl.span = span_function_body_scheduled;
    }
    mut function_stmt_idx_return_body_scheduled: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(function_stmt_idx_return_body_scheduled, function_stmt_return_body_scheduled);

    typechecker.check_statement(function_stmt_idx_return_body_scheduled, &env_return_body_scheduled, scope_return_body_scheduled, ctx);

    if len(env_return_body_scheduled.errors) != 0 {
        os.LogStr("Error: real function-body return defer scheduling should not emit diagnostics");
        os.LogStr(env_return_body_scheduled.errors[0].message);
        os.Exit(1);
    }

    mut env_implicit_body_scheduled := typechecker.env_new(ctx);
    env_implicit_body_scheduled.current_prefix = "main__";
    mut scope_implicit_body_scheduled := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct_linear_metadata(&env_implicit_body_scheduled, "main__DeferFunctionBodyPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_implicit_body_scheduled, "main__DeferFunctionBodyPayload", "close_defer_function_body_payload", ctx);

    mut decl_implicit_body_scheduled: ast.Statement[ctx];
    unsafe {
        decl_implicit_body_scheduled.tag = 4; // VarDecl
        decl_implicit_body_scheduled.VarDecl.name = "implicit_body_scheduled_resource";
        decl_implicit_body_scheduled.VarDecl.is_mut = 1;
        decl_implicit_body_scheduled.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        decl_implicit_body_scheduled.VarDecl.var_type = resource_type_idx_function_body_scheduled;
        decl_implicit_body_scheduled.VarDecl.span = span_function_body_scheduled;
    }

    mut lex_implicit_body_defer: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_implicit_body_defer, "defer close_defer_function_body_payload(implicit_body_scheduled_resource);");
    mut parser_implicit_body_defer: parser.Parser[ctx];
    parser.init_parser(&parser_implicit_body_defer, &lex_implicit_body_defer, ctx);
    mut defer_implicit_body_scheduled := parser.parse_statement(&parser_implicit_body_defer, ctx);

    mut body_statements_implicit_body_scheduled: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
    body_statements_implicit_body_scheduled.Push(decl_implicit_body_scheduled);
    body_statements_implicit_body_scheduled.Push(ctx[defer_implicit_body_scheduled]);
    mut body_statements_idx_implicit_body_scheduled: Index[std.Vector[ast.Statement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_statements_idx_implicit_body_scheduled, body_statements_implicit_body_scheduled);

    mut body_implicit_body_scheduled: ast.BlockStatement[ctx];
    body_implicit_body_scheduled.statements = body_statements_idx_implicit_body_scheduled;
    body_implicit_body_scheduled.span = span_function_body_scheduled;
    mut body_idx_implicit_body_scheduled: Index[ast.BlockStatement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_idx_implicit_body_scheduled, body_implicit_body_scheduled);

    mut params_implicit_body_scheduled: std.Vector[ast.Parameter[ctx], ctx] := std.VectorNew(ctx);
    mut params_idx_implicit_body_scheduled: Index[std.Vector[ast.Parameter[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(params_idx_implicit_body_scheduled, params_implicit_body_scheduled);

    mut function_stmt_implicit_body_scheduled: ast.Statement[ctx];
    unsafe {
        function_stmt_implicit_body_scheduled.tag = 3; // FunctionDecl
        function_stmt_implicit_body_scheduled.FunctionDecl.name = "defer_implicit_body_scheduled_resource";
        function_stmt_implicit_body_scheduled.FunctionDecl.is_unsafe = 0;
        function_stmt_implicit_body_scheduled.FunctionDecl.is_extern = 0;
        function_stmt_implicit_body_scheduled.FunctionDecl.extern_symbol_name = "";
        function_stmt_implicit_body_scheduled.FunctionDecl.extern_abi = "C";
        function_stmt_implicit_body_scheduled.FunctionDecl.requires_unsafe_call = 0;
        function_stmt_implicit_body_scheduled.FunctionDecl.requires_layout_metadata = 0;
        function_stmt_implicit_body_scheduled.FunctionDecl.requires_sandbox_arena = 0;
        function_stmt_implicit_body_scheduled.FunctionDecl.params = params_idx_implicit_body_scheduled;
        function_stmt_implicit_body_scheduled.FunctionDecl.return_type = return_type_idx_function_body_scheduled;
        function_stmt_implicit_body_scheduled.FunctionDecl.body = body_idx_implicit_body_scheduled;
        function_stmt_implicit_body_scheduled.FunctionDecl.span = span_function_body_scheduled;
    }
    mut function_stmt_idx_implicit_body_scheduled: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(function_stmt_idx_implicit_body_scheduled, function_stmt_implicit_body_scheduled);

    typechecker.check_statement(function_stmt_idx_implicit_body_scheduled, &env_implicit_body_scheduled, scope_implicit_body_scheduled, ctx);

    if len(env_implicit_body_scheduled.errors) != 0 {
        os.LogStr("Error: real function-body implicit-exit defer scheduling should not emit diagnostics");
        os.LogStr(env_implicit_body_scheduled.errors[0].message);
        os.Exit(1);
    }

    mut env_pending_control := typechecker.env_new(ctx);
    env_pending_control.current_prefix = "main__";
    mut scope_pending_control := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct_linear_metadata(&env_pending_control, "main__DeferFunctionBodyPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_pending_control, "main__DeferFunctionBodyPayload", "close_defer_function_body_payload", ctx);

    mut decl_pending_control: ast.Statement[ctx];
    unsafe {
        decl_pending_control.tag = 4; // VarDecl
        decl_pending_control.VarDecl.name = "pending_body_resource";
        decl_pending_control.VarDecl.is_mut = 1;
        decl_pending_control.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        decl_pending_control.VarDecl.var_type = resource_type_idx_function_body_scheduled;
        decl_pending_control.VarDecl.span = span_function_body_scheduled;
    }

    mut body_statements_pending_control: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
    body_statements_pending_control.Push(decl_pending_control);
    mut body_statements_idx_pending_control: Index[std.Vector[ast.Statement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_statements_idx_pending_control, body_statements_pending_control);

    mut body_pending_control: ast.BlockStatement[ctx];
    body_pending_control.statements = body_statements_idx_pending_control;
    body_pending_control.span = span_function_body_scheduled;
    mut body_idx_pending_control: Index[ast.BlockStatement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_idx_pending_control, body_pending_control);

    mut params_pending_control: std.Vector[ast.Parameter[ctx], ctx] := std.VectorNew(ctx);
    mut params_idx_pending_control: Index[std.Vector[ast.Parameter[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(params_idx_pending_control, params_pending_control);

    mut function_stmt_pending_control: ast.Statement[ctx];
    unsafe {
        function_stmt_pending_control.tag = 3; // FunctionDecl
        function_stmt_pending_control.FunctionDecl.name = "pending_body_control_resource";
        function_stmt_pending_control.FunctionDecl.is_unsafe = 0;
        function_stmt_pending_control.FunctionDecl.is_extern = 0;
        function_stmt_pending_control.FunctionDecl.extern_symbol_name = "";
        function_stmt_pending_control.FunctionDecl.extern_abi = "C";
        function_stmt_pending_control.FunctionDecl.requires_unsafe_call = 0;
        function_stmt_pending_control.FunctionDecl.requires_layout_metadata = 0;
        function_stmt_pending_control.FunctionDecl.requires_sandbox_arena = 0;
        function_stmt_pending_control.FunctionDecl.params = params_idx_pending_control;
        function_stmt_pending_control.FunctionDecl.return_type = return_type_idx_function_body_scheduled;
        function_stmt_pending_control.FunctionDecl.body = body_idx_pending_control;
        function_stmt_pending_control.FunctionDecl.span = span_function_body_scheduled;
    }
    mut function_stmt_idx_pending_control: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(function_stmt_idx_pending_control, function_stmt_pending_control);

    typechecker.check_statement(function_stmt_idx_pending_control, &env_pending_control, scope_pending_control, ctx);

    mut pending_control_missing_cleanup_count := 0;
    mut error_idx_pending_control := 0;
    while error_idx_pending_control < len(env_pending_control.errors) {
        mut msg_pending_control := env_pending_control.errors[error_idx_pending_control].message;
        if std.str_find(msg_pending_control, "LinearResourceMissingCleanup") != 0 - 1 {
            if std.str_find(msg_pending_control, "pending_body_resource") != 0 - 1 {
                pending_control_missing_cleanup_count = pending_control_missing_cleanup_count + 1;
            }
        }
        error_idx_pending_control = error_idx_pending_control + 1;
    }

    if pending_control_missing_cleanup_count != 1 {
        os.LogStr("Error: pending control function should still emit exactly one LinearResourceMissingCleanup");
        if len(env_pending_control.errors) > 0 {
            os.LogStr(env_pending_control.errors[0].message);
        }
        os.Exit(1);
    }

    os.LogStr("SUCCESS: real function-body scheduled Resource return and implicit-exit cleanup verified!");
}