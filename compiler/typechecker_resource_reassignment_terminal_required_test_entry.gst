import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_reassign := typechecker.env_new(ctx);
    env_reassign.current_prefix = "main__";
    mut scope_reassign := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_reassign, "main__ReassignPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_reassign, "main__ReassignPayload", "close_reassign_payload", ctx);

    mut span_reassign: token.Span;

    mut payload_reassign := typechecker.make_type_struct("main__ReassignPayload", "", ctx);
    mut resource_reassign := typechecker.make_type_resource(payload_reassign, ctx);
    mut resource_type_idx_reassign: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_reassign, resource_reassign);

    mut source_decl_reassign: ast.Statement[ctx];
    unsafe {
        source_decl_reassign.tag = 4; // VarDecl
        source_decl_reassign.VarDecl.name = "source_reassign_resource";
        source_decl_reassign.VarDecl.is_mut = 1;
        source_decl_reassign.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        source_decl_reassign.VarDecl.var_type = resource_type_idx_reassign;
        source_decl_reassign.VarDecl.span = span_reassign;
    }
    mut source_decl_idx_reassign: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(source_decl_idx_reassign, source_decl_reassign);
    typechecker.check_statement(source_decl_idx_reassign, &env_reassign, scope_reassign, ctx);

    mut target_decl_reassign: ast.Statement[ctx];
    unsafe {
        target_decl_reassign.tag = 4; // VarDecl
        target_decl_reassign.VarDecl.name = "target_reassign_resource";
        target_decl_reassign.VarDecl.is_mut = 1;
        target_decl_reassign.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        target_decl_reassign.VarDecl.var_type = resource_type_idx_reassign;
        target_decl_reassign.VarDecl.span = span_reassign;
    }
    mut target_decl_idx_reassign: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(target_decl_idx_reassign, target_decl_reassign);
    typechecker.check_statement(target_decl_idx_reassign, &env_reassign, scope_reassign, ctx);

    if typechecker.env_open_linear_resource_is_owned(&env_reassign, "target_reassign_resource", ctx) != 1 {
        os.LogStr("Error: reassignment target should start owned/open before overwrite rejection");
        os.Exit(1);
    }

    mut left_reassign: ast.Expression[ctx];
    unsafe {
        left_reassign.tag = 0; // Identifier
        left_reassign.Identifier.name = "target_reassign_resource";
        left_reassign.Identifier.span = span_reassign;
    }
    mut left_idx_reassign: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(left_idx_reassign, left_reassign);

    mut value_reassign: ast.Expression[ctx];
    unsafe {
        value_reassign.tag = 0; // Identifier
        value_reassign.Identifier.name = "source_reassign_resource";
        value_reassign.Identifier.span = span_reassign;
    }
    mut value_idx_reassign: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(value_idx_reassign, value_reassign);

    mut stmt_reassign: ast.Statement[ctx];
    unsafe {
        stmt_reassign.tag = 5; // Assignment
        stmt_reassign.Assignment.left = left_idx_reassign;
        stmt_reassign.Assignment.value = value_idx_reassign;
        stmt_reassign.Assignment.span = span_reassign;
    }
    mut stmt_idx_reassign: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(stmt_idx_reassign, stmt_reassign);
    typechecker.check_statement(stmt_idx_reassign, &env_reassign, scope_reassign, ctx);

    if len(env_reassign.errors) != 1 {
        os.LogStr("Error: reassignment over open Resource should produce exactly one diagnostic");
        os.Exit(1);
    }
    if std.str_find(env_reassign.errors[0].message, "LinearResourceMissingCleanup") == 0 - 1 {
        os.LogStr("Error: reassignment over open Resource should report LinearResourceMissingCleanup");
        os.LogStr(env_reassign.errors[0].message);
        os.Exit(1);
    }
    if std.str_find(env_reassign.errors[0].message, "before reassignment") == 0 - 1 {
        os.LogStr("Error: reassignment over open Resource diagnostic should mention reassignment boundary");
        os.LogStr(env_reassign.errors[0].message);
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_moved(&env_reassign, "source_reassign_resource", ctx) != 0 {
        os.LogStr("Error: failed reassignment must not move the source Resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_reassign, "target_reassign_resource", ctx) != 1 {
        os.LogStr("Error: failed reassignment must leave the old target Resource owned/open");
        os.Exit(1);
    }

    typechecker.env_mark_open_linear_resource_closed(&env_reassign, "target_reassign_resource", ctx);
    mut err_count_after_reject := len(env_reassign.errors);
    typechecker.check_statement(stmt_idx_reassign, &env_reassign, scope_reassign, ctx);

    if len(env_reassign.errors) != err_count_after_reject {
        os.LogStr("Error: reassignment after terminal old value must not add a new diagnostic");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_moved(&env_reassign, "source_reassign_resource", ctx) != 1 {
        os.LogStr("Error: reassignment after terminal old value should move the source Resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_reassign, "target_reassign_resource", ctx) != 1 {
        os.LogStr("Error: reassignment after terminal old value should reopen the destination Resource");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource reassignment terminal requirement verified!");
}