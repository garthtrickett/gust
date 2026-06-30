import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_move_assignment := typechecker.env_new(ctx);
    env_move_assignment.current_prefix = "main__";
    mut scope_move_assignment := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_move_assignment, "main__MoveAssignmentPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_move_assignment, "main__MoveAssignmentPayload", "close_move_assignment_payload", ctx);

    mut span_move_assignment: token.Span;

    mut payload_move_assignment := typechecker.make_type_struct("main__MoveAssignmentPayload", "", ctx);
    mut resource_move_assignment := typechecker.make_type_resource(payload_move_assignment, ctx);
    mut resource_type_idx_move_assignment: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_move_assignment, resource_move_assignment);

    mut source_decl_move_assignment: ast.Statement[ctx];
    unsafe {
        source_decl_move_assignment.tag = 4; // VarDecl
        source_decl_move_assignment.VarDecl.name = "source_move_resource";
        source_decl_move_assignment.VarDecl.is_mut = 1;
        source_decl_move_assignment.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        source_decl_move_assignment.VarDecl.var_type = resource_type_idx_move_assignment;
        source_decl_move_assignment.VarDecl.span = span_move_assignment;
    }
    mut source_decl_idx_move_assignment: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(source_decl_idx_move_assignment, source_decl_move_assignment);
    typechecker.check_statement(source_decl_idx_move_assignment, &env_move_assignment, scope_move_assignment, ctx);

    mut target_decl_move_assignment: ast.Statement[ctx];
    unsafe {
        target_decl_move_assignment.tag = 4; // VarDecl
        target_decl_move_assignment.VarDecl.name = "target_move_resource";
        target_decl_move_assignment.VarDecl.is_mut = 1;
        target_decl_move_assignment.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        target_decl_move_assignment.VarDecl.var_type = resource_type_idx_move_assignment;
        target_decl_move_assignment.VarDecl.span = span_move_assignment;
    }
    mut target_decl_idx_move_assignment: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(target_decl_idx_move_assignment, target_decl_move_assignment);
    typechecker.check_statement(target_decl_idx_move_assignment, &env_move_assignment, scope_move_assignment, ctx);

    if typechecker.env_open_linear_resource_is_owned(&env_move_assignment, "source_move_resource", ctx) != 1 {
        os.LogStr("Error: source Resource must start owned before move assignment");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_move_assignment, "target_move_resource", ctx) != 1 {
        os.LogStr("Error: target Resource must start owned before move assignment");
        os.Exit(1);
    }
    typechecker.env_mark_open_linear_resource_closed(&env_move_assignment, "target_move_resource", ctx);

    mut assign_left_move_assignment: ast.Expression[ctx];
    unsafe {
        assign_left_move_assignment.tag = 0; // Identifier
        assign_left_move_assignment.Identifier.name = "target_move_resource";
        assign_left_move_assignment.Identifier.span = span_move_assignment;
    }
    mut assign_left_idx_move_assignment: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(assign_left_idx_move_assignment, assign_left_move_assignment);

    mut assign_value_move_assignment: ast.Expression[ctx];
    unsafe {
        assign_value_move_assignment.tag = 0; // Identifier
        assign_value_move_assignment.Identifier.name = "source_move_resource";
        assign_value_move_assignment.Identifier.span = span_move_assignment;
    }
    mut assign_value_idx_move_assignment: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(assign_value_idx_move_assignment, assign_value_move_assignment);

    mut assign_stmt_move_assignment: ast.Statement[ctx];
    unsafe {
        assign_stmt_move_assignment.tag = 5; // Assignment
        assign_stmt_move_assignment.Assignment.left = assign_left_idx_move_assignment;
        assign_stmt_move_assignment.Assignment.value = assign_value_idx_move_assignment;
        assign_stmt_move_assignment.Assignment.span = span_move_assignment;
    }
    mut assign_stmt_idx_move_assignment: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(assign_stmt_idx_move_assignment, assign_stmt_move_assignment);
    typechecker.check_statement(assign_stmt_idx_move_assignment, &env_move_assignment, scope_move_assignment, ctx);

    if typechecker.env_open_linear_resource_is_moved(&env_move_assignment, "source_move_resource", ctx) != 1 {
        os.LogStr("Error: Resource assignment did not mark source as moved");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_move_assignment, "target_move_resource", ctx) != 1 {
        os.LogStr("Error: Resource assignment did not leave target in owned/open state");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_open_linear_resource_destructor_name(&env_move_assignment, "target_move_resource", ctx), "close_move_assignment_payload") == 0 {
        os.LogStr("Error: Resource move assignment did not preserve target destructor identity");
        os.Exit(1);
    }


    if len(env_move_assignment.errors) != 0 {
        os.LogStr("Error: Resource move assignment tracking produced unexpected typechecker error");
        os.LogStr(env_move_assignment.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource move assignment tracking verified!");
}
