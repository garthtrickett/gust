import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func env_has_error_containing(env: *typechecker.TypeEnvironment[ctx], needle: str, ctx: &Arena) int {
    unsafe {
        mut i := 0;
        while i < len((*env).errors) {
            mut msg := (*env).errors[i].message;
            if std.str_find(msg, needle) != 0 - 1 {
                return 1;
            }
            i = i + 1;
        }
        return 0;
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span_dir_cleanup_route: token.Span;

    mut env_helper_route := typechecker.env_new(ctx);
    env_helper_route.current_prefix = "main__";
    if typechecker.env_shadow_track_open_directory_resource(&env_helper_route, "helper_route_dir", "os_Dir_ctx", ctx) != 1 {
        os.LogStr("Error: directory cleanup routing fixture should open a shadow-tracked directory Resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_requires_cleanup(&env_helper_route, "helper_route_dir", ctx) != 1 {
        os.LogStr("Error: directory shadow should reuse Resource cleanup-required transition predicate");
        os.Exit(1);
    }
    if typechecker.env_open_directory_resource_requires_cleanup(&env_helper_route, "helper_route_dir", ctx) != 1 {
        os.LogStr("Error: directory cleanup routing helper should see pending directory cleanup");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resources_have_pending_cleanup(&env_helper_route, ctx) != 0 {
        os.LogStr("Error: generic Resource cleanup boundary should skip directory shadow records");
        os.Exit(1);
    }
    typechecker.env_validate_linear_resource_scope_exit_cleanup(&env_helper_route, span_dir_cleanup_route, ctx);
    if env_has_error_containing(&env_helper_route, "LinearResourceMissingCleanup", ctx) == 1 {
        os.LogStr("Error: generic Resource cleanup boundary should not emit LinearResourceMissingCleanup for directory shadows");
        if len(env_helper_route.errors) > 0 {
            os.LogStr(env_helper_route.errors[0].message);
        }
        os.Exit(1);
    }
    if typechecker.env_shadow_track_closed_directory_resource(&env_helper_route, "helper_route_dir", ctx) != 1 {
        os.LogStr("Error: directory cleanup routing fixture should close the directory shadow Resource");
        os.Exit(1);
    }
    if typechecker.env_open_directory_resource_requires_cleanup(&env_helper_route, "helper_route_dir", ctx) != 0 {
        os.LogStr("Error: closed directory shadow should not require cleanup");
        os.Exit(1);
    }

    mut env_function_route := typechecker.env_new(ctx);
    env_function_route.current_prefix = "main__";
    mut scope_function_route := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut dir_type_route := typechecker.make_type_struct("os_Dir_ctx", "ctx", ctx);
    mut dir_type_idx_route: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(dir_type_idx_route, dir_type_route);

    mut decl_function_route: ast.Statement[ctx];
    unsafe {
        decl_function_route.tag = 4; // VarDecl
        decl_function_route.VarDecl.name = "function_route_dir";
        decl_function_route.VarDecl.is_mut = 1;
        decl_function_route.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        decl_function_route.VarDecl.var_type = dir_type_idx_route;
        decl_function_route.VarDecl.span = span_dir_cleanup_route;
    }

    mut body_statements_function_route: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
    body_statements_function_route.Push(decl_function_route);
    mut body_statements_idx_function_route: Index[std.Vector[ast.Statement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_statements_idx_function_route, body_statements_function_route);

    mut body_function_route: ast.BlockStatement[ctx];
    body_function_route.statements = body_statements_idx_function_route;
    body_function_route.span = span_dir_cleanup_route;
    mut body_idx_function_route: Index[ast.BlockStatement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_idx_function_route, body_function_route);

    mut params_function_route: std.Vector[ast.Parameter[ctx], ctx] := std.VectorNew(ctx);
    mut params_idx_function_route: Index[std.Vector[ast.Parameter[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(params_idx_function_route, params_function_route);

    mut return_type_function_route: ast.Type[ctx];
    unsafe {
        return_type_function_route.tag = 3; // Void
    }
    mut return_type_idx_function_route: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(return_type_idx_function_route, return_type_function_route);

    mut function_stmt_route: ast.Statement[ctx];
    unsafe {
        function_stmt_route.tag = 3; // FunctionDecl
        function_stmt_route.FunctionDecl.name = "directory_cleanup_boundary_route";
        function_stmt_route.FunctionDecl.is_unsafe = 0;
        function_stmt_route.FunctionDecl.is_extern = 0;
        function_stmt_route.FunctionDecl.extern_symbol_name = "";
        function_stmt_route.FunctionDecl.extern_abi = "C";
        function_stmt_route.FunctionDecl.requires_unsafe_call = 0;
        function_stmt_route.FunctionDecl.requires_layout_metadata = 0;
        function_stmt_route.FunctionDecl.requires_sandbox_arena = 0;
        function_stmt_route.FunctionDecl.params = params_idx_function_route;
        function_stmt_route.FunctionDecl.return_type = return_type_idx_function_route;
        function_stmt_route.FunctionDecl.body = body_idx_function_route;
        function_stmt_route.FunctionDecl.span = span_dir_cleanup_route;
    }
    mut function_stmt_idx_route: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(function_stmt_idx_route, function_stmt_route);

    typechecker.check_statement(function_stmt_idx_route, &env_function_route, scope_function_route, ctx);

    if env_has_error_containing(&env_function_route, "must be cleanly closed with os.CloseDir before leaving local scope", ctx) != 1 {
        os.LogStr("Error: routed directory cleanup boundary should preserve legacy CloseDir diagnostic");
        if len(env_function_route.errors) > 0 {
            os.LogStr(env_function_route.errors[0].message);
        }
        os.Exit(1);
    }
    if env_has_error_containing(&env_function_route, "function_route_dir", ctx) != 1 {
        os.LogStr("Error: routed directory cleanup boundary should name the leaked directory");
        if len(env_function_route.errors) > 0 {
            os.LogStr(env_function_route.errors[0].message);
        }
        os.Exit(1);
    }
    if env_has_error_containing(&env_function_route, "LinearResourceMissingCleanup", ctx) == 1 {
        os.LogStr("Error: routed directory cleanup boundary should not duplicate generic Resource cleanup diagnostics");
        if len(env_function_route.errors) > 0 {
            os.LogStr(env_function_route.errors[0].message);
        }
        os.Exit(1);
    }

    os.LogStr("SUCCESS: directory cleanup-boundary checks routed through Resource helpers!");
}