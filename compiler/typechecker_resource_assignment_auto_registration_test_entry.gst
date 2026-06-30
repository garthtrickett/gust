import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_auto_assign := typechecker.env_new(ctx);
    env_auto_assign.current_prefix = "main__";
    mut scope_auto_assign := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_auto_assign, "main__AutoAssignPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_auto_assign, "main__AutoAssignPayload", "close_auto_assign_payload", ctx);
    typechecker.env_register_struct_linear_metadata(&env_auto_assign, "main__AutoAssignPlainPayload", 0, ctx);

    mut span_auto_assign: token.Span;

    mut payload_auto_assign := typechecker.make_type_struct("main__AutoAssignPayload", "", ctx);
    mut resource_auto_assign := typechecker.make_type_resource(payload_auto_assign, ctx);

    typechecker.scope_insert(scope_auto_assign, "target_auto_assign_resource", resource_auto_assign, ctx);
    env_auto_assign.variable_types.Insert(std.Clone(ctx, "target_auto_assign_resource"), resource_auto_assign);
    typechecker.scope_insert(scope_auto_assign, "source_auto_assign_resource", resource_auto_assign, ctx);
    env_auto_assign.variable_types.Insert(std.Clone(ctx, "source_auto_assign_resource"), resource_auto_assign);

    if typechecker.env_open_linear_resource_is_tracked(&env_auto_assign, "target_auto_assign_resource", ctx) != 0 {
        os.LogStr("Error: assignment target should start untracked before automatic Resource assignment registration");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_tracked(&env_auto_assign, "source_auto_assign_resource", ctx) != 0 {
        os.LogStr("Error: assignment source should start untracked in assignment-registration-only fixture");
        os.Exit(1);
    }

    mut assign_left_auto_assign: ast.Expression[ctx];
    unsafe {
        assign_left_auto_assign.tag = 0; // Identifier
        assign_left_auto_assign.Identifier.name = "target_auto_assign_resource";
        assign_left_auto_assign.Identifier.span = span_auto_assign;
    }
    mut assign_left_idx_auto_assign: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(assign_left_idx_auto_assign, assign_left_auto_assign);

    mut assign_value_auto_assign: ast.Expression[ctx];
    unsafe {
        assign_value_auto_assign.tag = 0; // Identifier
        assign_value_auto_assign.Identifier.name = "source_auto_assign_resource";
        assign_value_auto_assign.Identifier.span = span_auto_assign;
    }
    mut assign_value_idx_auto_assign: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(assign_value_idx_auto_assign, assign_value_auto_assign);

    mut assign_stmt_auto_assign: ast.Statement[ctx];
    unsafe {
        assign_stmt_auto_assign.tag = 5; // Assignment
        assign_stmt_auto_assign.Assignment.left = assign_left_idx_auto_assign;
        assign_stmt_auto_assign.Assignment.value = assign_value_idx_auto_assign;
        assign_stmt_auto_assign.Assignment.span = span_auto_assign;
    }
    mut assign_stmt_idx_auto_assign: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(assign_stmt_idx_auto_assign, assign_stmt_auto_assign);
    typechecker.check_statement(assign_stmt_idx_auto_assign, &env_auto_assign, scope_auto_assign, ctx);

    if typechecker.env_open_linear_resource_is_owned(&env_auto_assign, "target_auto_assign_resource", ctx) != 1 {
        os.LogStr("Error: explicit tracking-eligible Resource assignment did not automatically register destination as owned/open");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_open_linear_resource_destructor_name(&env_auto_assign, "target_auto_assign_resource", ctx), "close_auto_assign_payload") == 0 {
        os.LogStr("Error: automatic Resource assignment registration did not preserve destination destructor identity");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_tracked(&env_auto_assign, "source_auto_assign_resource", ctx) != 0 {
        os.LogStr("Error: assignment-registration-only fixture must not move/register an untracked source Resource yet");
        os.Exit(1);
    }

    mut plain_payload_auto_assign := typechecker.make_type_struct("main__AutoAssignPlainPayload", "", ctx);
    mut plain_resource_auto_assign := typechecker.make_type_resource(plain_payload_auto_assign, ctx);
    typechecker.scope_insert(scope_auto_assign, "target_plain_auto_assign_resource", plain_resource_auto_assign, ctx);
    env_auto_assign.variable_types.Insert(std.Clone(ctx, "target_plain_auto_assign_resource"), plain_resource_auto_assign);
    typechecker.scope_insert(scope_auto_assign, "source_plain_auto_assign_resource", plain_resource_auto_assign, ctx);
    env_auto_assign.variable_types.Insert(std.Clone(ctx, "source_plain_auto_assign_resource"), plain_resource_auto_assign);

    mut plain_left_auto_assign: ast.Expression[ctx];
    unsafe {
        plain_left_auto_assign.tag = 0; // Identifier
        plain_left_auto_assign.Identifier.name = "target_plain_auto_assign_resource";
        plain_left_auto_assign.Identifier.span = span_auto_assign;
    }
    mut plain_left_idx_auto_assign: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(plain_left_idx_auto_assign, plain_left_auto_assign);

    mut plain_value_auto_assign: ast.Expression[ctx];
    unsafe {
        plain_value_auto_assign.tag = 0; // Identifier
        plain_value_auto_assign.Identifier.name = "source_plain_auto_assign_resource";
        plain_value_auto_assign.Identifier.span = span_auto_assign;
    }
    mut plain_value_idx_auto_assign: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(plain_value_idx_auto_assign, plain_value_auto_assign);

    mut plain_stmt_auto_assign: ast.Statement[ctx];
    unsafe {
        plain_stmt_auto_assign.tag = 5; // Assignment
        plain_stmt_auto_assign.Assignment.left = plain_left_idx_auto_assign;
        plain_stmt_auto_assign.Assignment.value = plain_value_idx_auto_assign;
        plain_stmt_auto_assign.Assignment.span = span_auto_assign;
    }
    mut plain_stmt_idx_auto_assign: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(plain_stmt_idx_auto_assign, plain_stmt_auto_assign);
    typechecker.check_statement(plain_stmt_idx_auto_assign, &env_auto_assign, scope_auto_assign, ctx);

    if typechecker.env_open_linear_resource_is_tracked(&env_auto_assign, "target_plain_auto_assign_resource", ctx) != 0 {
        os.LogStr("Error: Resource assignment with non-tracking payload must not automatically register destination");
        os.Exit(1);
    }

    mut ordinary_type_auto_assign := typechecker.make_type_struct("main__AutoAssignOrdinary", "", ctx);
    typechecker.scope_insert(scope_auto_assign, "target_ordinary_auto_assign_value", ordinary_type_auto_assign, ctx);
    env_auto_assign.variable_types.Insert(std.Clone(ctx, "target_ordinary_auto_assign_value"), ordinary_type_auto_assign);
    typechecker.scope_insert(scope_auto_assign, "source_ordinary_auto_assign_value", ordinary_type_auto_assign, ctx);
    env_auto_assign.variable_types.Insert(std.Clone(ctx, "source_ordinary_auto_assign_value"), ordinary_type_auto_assign);

    mut ordinary_left_auto_assign: ast.Expression[ctx];
    unsafe {
        ordinary_left_auto_assign.tag = 0; // Identifier
        ordinary_left_auto_assign.Identifier.name = "target_ordinary_auto_assign_value";
        ordinary_left_auto_assign.Identifier.span = span_auto_assign;
    }
    mut ordinary_left_idx_auto_assign: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(ordinary_left_idx_auto_assign, ordinary_left_auto_assign);

    mut ordinary_value_auto_assign: ast.Expression[ctx];
    unsafe {
        ordinary_value_auto_assign.tag = 0; // Identifier
        ordinary_value_auto_assign.Identifier.name = "source_ordinary_auto_assign_value";
        ordinary_value_auto_assign.Identifier.span = span_auto_assign;
    }
    mut ordinary_value_idx_auto_assign: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(ordinary_value_idx_auto_assign, ordinary_value_auto_assign);

    mut ordinary_stmt_auto_assign: ast.Statement[ctx];
    unsafe {
        ordinary_stmt_auto_assign.tag = 5; // Assignment
        ordinary_stmt_auto_assign.Assignment.left = ordinary_left_idx_auto_assign;
        ordinary_stmt_auto_assign.Assignment.value = ordinary_value_idx_auto_assign;
        ordinary_stmt_auto_assign.Assignment.span = span_auto_assign;
    }
    mut ordinary_stmt_idx_auto_assign: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(ordinary_stmt_idx_auto_assign, ordinary_stmt_auto_assign);
    typechecker.check_statement(ordinary_stmt_idx_auto_assign, &env_auto_assign, scope_auto_assign, ctx);

    if typechecker.env_open_linear_resource_is_tracked(&env_auto_assign, "target_ordinary_auto_assign_value", ctx) != 0 {
        os.LogStr("Error: ordinary non-Resource assignment must not enter open_linear_resources");
        os.Exit(1);
    }

    if len(env_auto_assign.errors) != 0 {
        os.LogStr("Error: Resource assignment auto-registration produced unexpected typechecker error");
        os.LogStr(env_auto_assign.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource assignment auto-registration verified!");
}