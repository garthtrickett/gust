import "ast.gst" as ast;
import "token.gst" as token;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_auto_decl := typechecker.env_new(ctx);
    env_auto_decl.current_prefix = "main__";
    mut scope_auto_decl := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    typechecker.env_register_struct_linear_metadata(&env_auto_decl, "main__AutoDeclPayload", 1, ctx);
    typechecker.env_register_struct_linear_destructor(&env_auto_decl, "main__AutoDeclPayload", "close_auto_decl_payload", ctx);
    typechecker.env_register_struct_linear_metadata(&env_auto_decl, "main__AutoDeclPlainPayload", 0, ctx);

    mut span_auto_decl: token.Span;

    mut payload_auto_decl := typechecker.make_type_struct("main__AutoDeclPayload", "", ctx);
    mut resource_auto_decl := typechecker.make_type_resource(payload_auto_decl, ctx);
    mut resource_type_idx_auto_decl: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(resource_type_idx_auto_decl, resource_auto_decl);

    mut tracked_decl_stmt_auto_decl: ast.Statement[ctx];
    unsafe {
        tracked_decl_stmt_auto_decl.tag = 4; // VarDecl
        tracked_decl_stmt_auto_decl.VarDecl.name = "auto_decl_resource";
        tracked_decl_stmt_auto_decl.VarDecl.is_mut = 1;
        tracked_decl_stmt_auto_decl.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        tracked_decl_stmt_auto_decl.VarDecl.var_type = resource_type_idx_auto_decl;
        tracked_decl_stmt_auto_decl.VarDecl.span = span_auto_decl;
    }
    mut tracked_decl_stmt_idx_auto_decl: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(tracked_decl_stmt_idx_auto_decl, tracked_decl_stmt_auto_decl);
    typechecker.check_statement(tracked_decl_stmt_idx_auto_decl, &env_auto_decl, scope_auto_decl, ctx);

    if typechecker.env_open_linear_resource_is_owned(&env_auto_decl, "auto_decl_resource", ctx) != 1 {
        os.LogStr("Error: explicit tracking-eligible Resource declaration did not automatically register as owned/open");
        os.Exit(1);
    }
    if std.str_eq(typechecker.env_open_linear_resource_destructor_name(&env_auto_decl, "auto_decl_resource", ctx), "close_auto_decl_payload") == 0 {
        os.LogStr("Error: automatic Resource declaration registration did not preserve destructor identity");
        os.Exit(1);
    }

    mut plain_payload_auto_decl := typechecker.make_type_struct("main__AutoDeclPlainPayload", "", ctx);
    mut plain_resource_auto_decl := typechecker.make_type_resource(plain_payload_auto_decl, ctx);
    mut plain_resource_type_idx_auto_decl: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(plain_resource_type_idx_auto_decl, plain_resource_auto_decl);

    mut plain_resource_decl_stmt_auto_decl: ast.Statement[ctx];
    unsafe {
        plain_resource_decl_stmt_auto_decl.tag = 4; // VarDecl
        plain_resource_decl_stmt_auto_decl.VarDecl.name = "auto_decl_plain_resource";
        plain_resource_decl_stmt_auto_decl.VarDecl.is_mut = 1;
        plain_resource_decl_stmt_auto_decl.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        plain_resource_decl_stmt_auto_decl.VarDecl.var_type = plain_resource_type_idx_auto_decl;
        plain_resource_decl_stmt_auto_decl.VarDecl.span = span_auto_decl;
    }
    mut plain_resource_decl_stmt_idx_auto_decl: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(plain_resource_decl_stmt_idx_auto_decl, plain_resource_decl_stmt_auto_decl);
    typechecker.check_statement(plain_resource_decl_stmt_idx_auto_decl, &env_auto_decl, scope_auto_decl, ctx);

    if typechecker.env_open_linear_resource_is_tracked(&env_auto_decl, "auto_decl_plain_resource", ctx) != 0 {
        os.LogStr("Error: Resource declaration with non-tracking payload must not automatically register");
        os.Exit(1);
    }

    mut ordinary_type_auto_decl := typechecker.make_type_struct("main__AutoDeclOrdinary", "", ctx);
    mut ordinary_type_idx_auto_decl: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(ordinary_type_idx_auto_decl, ordinary_type_auto_decl);

    mut ordinary_decl_stmt_auto_decl: ast.Statement[ctx];
    unsafe {
        ordinary_decl_stmt_auto_decl.tag = 4; // VarDecl
        ordinary_decl_stmt_auto_decl.VarDecl.name = "auto_decl_ordinary_value";
        ordinary_decl_stmt_auto_decl.VarDecl.is_mut = 1;
        ordinary_decl_stmt_auto_decl.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        ordinary_decl_stmt_auto_decl.VarDecl.var_type = ordinary_type_idx_auto_decl;
        ordinary_decl_stmt_auto_decl.VarDecl.span = span_auto_decl;
    }
    mut ordinary_decl_stmt_idx_auto_decl: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(ordinary_decl_stmt_idx_auto_decl, ordinary_decl_stmt_auto_decl);
    typechecker.check_statement(ordinary_decl_stmt_idx_auto_decl, &env_auto_decl, scope_auto_decl, ctx);

    if typechecker.env_open_linear_resource_is_tracked(&env_auto_decl, "auto_decl_ordinary_value", ctx) != 0 {
        os.LogStr("Error: ordinary non-Resource declaration must not enter open_linear_resources");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: compiler-backed Resource declaration auto-registration verified!");
}