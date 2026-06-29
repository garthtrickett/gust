import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_tracking := typechecker.env_new(ctx);
    env_tracking.current_prefix = "main__";
    mut scope_tracking := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_tracking, "main__TrackingPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_tracking, "main__TrackingPayload", "close_tracking_payload", ctx);
    typechecker.env_register_struct_linear_metadata(&env_tracking, "main__PlainTrackingPayload", 0, ctx);

    mut span_tracking: token.Span;

    mut payload_tracking := typechecker.make_type_struct("main__TrackingPayload", "", ctx);
    mut resource_tracking := typechecker.make_type_resource(payload_tracking, ctx);
    mut resource_tracking_type_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_tracking_type_idx, resource_tracking);

    mut decl_stmt_tracking: ast.Statement[ctx];
    unsafe {
        decl_stmt_tracking.tag = 4; // VarDecl
        decl_stmt_tracking.VarDecl.name = "tracked_decl_resource";
        decl_stmt_tracking.VarDecl.is_mut = 1;
        decl_stmt_tracking.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        decl_stmt_tracking.VarDecl.var_type = resource_tracking_type_idx;
        decl_stmt_tracking.VarDecl.span = span_tracking;
    }
    mut decl_stmt_idx_tracking: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(decl_stmt_idx_tracking, decl_stmt_tracking);
    typechecker.check_statement(decl_stmt_idx_tracking, &env_tracking, scope_tracking, ctx);

    if typechecker.env_open_linear_resource_is_owned(&env_tracking, "tracked_decl_resource", ctx) != 1 {
        os.LogStr("Error: Resource declaration did not enter open_linear_resources through check_statement");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_open_linear_resource_destructor_name(&env_tracking, "tracked_decl_resource", ctx), "close_tracking_payload") == 0 {
        os.LogStr("Error: Resource declaration tracking did not preserve destructor identity");
        os.Exit(1);
    }

    mut plain_payload_tracking := typechecker.make_type_struct("main__PlainTrackingPayload", "", ctx);
    mut plain_resource_tracking := typechecker.make_type_resource(plain_payload_tracking, ctx);
    mut plain_resource_type_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(plain_resource_type_idx, plain_resource_tracking);

    mut plain_decl_stmt_tracking: ast.Statement[ctx];
    unsafe {
        plain_decl_stmt_tracking.tag = 4; // VarDecl
        plain_decl_stmt_tracking.VarDecl.name = "plain_decl_resource";
        plain_decl_stmt_tracking.VarDecl.is_mut = 1;
        plain_decl_stmt_tracking.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        plain_decl_stmt_tracking.VarDecl.var_type = plain_resource_type_idx;
        plain_decl_stmt_tracking.VarDecl.span = span_tracking;
    }
    mut plain_decl_stmt_idx_tracking: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(plain_decl_stmt_idx_tracking, plain_decl_stmt_tracking);
    typechecker.check_statement(plain_decl_stmt_idx_tracking, &env_tracking, scope_tracking, ctx);

    if typechecker.env_open_linear_resource_is_tracked(&env_tracking, "plain_decl_resource", ctx) != 0 {
        os.LogStr("Error: Resource declaration for plain payload must not enter open_linear_resources");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_tracking, "tracked_assign_resource", resource_tracking, ctx);
    env_tracking.variable_types.Insert(std.Clone(ctx, "tracked_assign_resource"), resource_tracking);

    mut assign_left_expr_tracking: ast.Expression[ctx];
    unsafe {
        assign_left_expr_tracking.tag = 0; // Identifier
        assign_left_expr_tracking.Identifier.name = "tracked_assign_resource";
        assign_left_expr_tracking.Identifier.span = span_tracking;
    }
    mut assign_left_idx_tracking: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(assign_left_idx_tracking, assign_left_expr_tracking);

    mut assign_value_expr_tracking: ast.Expression[ctx];
    unsafe {
        assign_value_expr_tracking.tag = 13; // Empty
        assign_value_expr_tracking.Empty.target_type = resource_tracking_type_idx;
        assign_value_expr_tracking.Empty.span = span_tracking;
    }
    mut assign_value_idx_tracking: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(assign_value_idx_tracking, assign_value_expr_tracking);

    mut assign_stmt_tracking: ast.Statement[ctx];
    unsafe {
        assign_stmt_tracking.tag = 5; // Assignment
        assign_stmt_tracking.Assignment.left = assign_left_idx_tracking;
        assign_stmt_tracking.Assignment.value = assign_value_idx_tracking;
        assign_stmt_tracking.Assignment.span = span_tracking;
    }
    mut assign_stmt_idx_tracking: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(assign_stmt_idx_tracking, assign_stmt_tracking);
    typechecker.check_statement(assign_stmt_idx_tracking, &env_tracking, scope_tracking, ctx);

    if typechecker.env_open_linear_resource_is_owned(&env_tracking, "tracked_assign_resource", ctx) != 1 {
        os.LogStr("Error: Resource assignment did not enter open_linear_resources through check_statement");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_open_linear_resource_destructor_name(&env_tracking, "tracked_assign_resource", ctx), "close_tracking_payload") == 0 {
        os.LogStr("Error: Resource assignment tracking did not preserve destructor identity");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_tracking, "plain_assign_resource", plain_resource_tracking, ctx);
    env_tracking.variable_types.Insert(std.Clone(ctx, "plain_assign_resource"), plain_resource_tracking);

    mut plain_assign_left_expr_tracking: ast.Expression[ctx];
    unsafe {
        plain_assign_left_expr_tracking.tag = 0; // Identifier
        plain_assign_left_expr_tracking.Identifier.name = "plain_assign_resource";
        plain_assign_left_expr_tracking.Identifier.span = span_tracking;
    }
    mut plain_assign_left_idx_tracking: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(plain_assign_left_idx_tracking, plain_assign_left_expr_tracking);

    mut plain_assign_value_expr_tracking: ast.Expression[ctx];
    unsafe {
        plain_assign_value_expr_tracking.tag = 13; // Empty
        plain_assign_value_expr_tracking.Empty.target_type = plain_resource_type_idx;
        plain_assign_value_expr_tracking.Empty.span = span_tracking;
    }
    mut plain_assign_value_idx_tracking: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(plain_assign_value_idx_tracking, plain_assign_value_expr_tracking);

    mut plain_assign_stmt_tracking: ast.Statement[ctx];
    unsafe {
        plain_assign_stmt_tracking.tag = 5; // Assignment
        plain_assign_stmt_tracking.Assignment.left = plain_assign_left_idx_tracking;
        plain_assign_stmt_tracking.Assignment.value = plain_assign_value_idx_tracking;
        plain_assign_stmt_tracking.Assignment.span = span_tracking;
    }
    mut plain_assign_stmt_idx_tracking: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(plain_assign_stmt_idx_tracking, plain_assign_stmt_tracking);
    typechecker.check_statement(plain_assign_stmt_idx_tracking, &env_tracking, scope_tracking, ctx);

    if typechecker.env_open_linear_resource_is_tracked(&env_tracking, "plain_assign_resource", ctx) != 0 {
        os.LogStr("Error: Resource assignment for plain payload must not enter open_linear_resources");
        os.Exit(1);
    }

    if len(env_tracking.errors) != 0 {
        os.LogStr("Error: Resource declaration/assignment tracking produced unexpected typechecker error");
        os.LogStr(env_tracking.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource declaration/assignment tracking verified!");
}