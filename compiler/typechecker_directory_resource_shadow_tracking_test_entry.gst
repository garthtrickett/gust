import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
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

    mut span_dir_shadow: token.Span;
    mut dir_type_shadow := typechecker.make_type_struct("os_Dir_ctx", "ctx", ctx);
    mut dir_type_idx_shadow: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(dir_type_idx_shadow, dir_type_shadow);

    mut env_decl_shadow := typechecker.env_new(ctx);
    env_decl_shadow.current_prefix = "main__";
    mut scope_decl_shadow := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    mut decl_shadow: ast.Statement[ctx];
    unsafe {
        decl_shadow.tag = 4; // VarDecl
        decl_shadow.VarDecl.name = "shadow_decl_dir";
        decl_shadow.VarDecl.is_mut = 1;
        decl_shadow.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        decl_shadow.VarDecl.var_type = dir_type_idx_shadow;
        decl_shadow.VarDecl.span = span_dir_shadow;
    }
    mut decl_shadow_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(decl_shadow_idx, decl_shadow);

    typechecker.check_statement(decl_shadow_idx, &env_decl_shadow, scope_decl_shadow, ctx);

    if env_decl_shadow.open_directories.Get("shadow_decl_dir").Ok == false {
        os.LogStr("Error: legacy directory declaration should still populate open_directories");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_owned(&env_decl_shadow, "shadow_decl_dir", ctx) != 1 {
        os.LogStr("Error: directory declaration should shadow-track an owned open_linear_resource");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_directory_shadow(&env_decl_shadow, "shadow_decl_dir", ctx) != 1 {
        os.LogStr("Error: directory declaration shadow record should be marked as directory shadow");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_requires_cleanup(&env_decl_shadow, "shadow_decl_dir", ctx) != 1 {
        os.LogStr("Error: directory shadow records should require cleanup through the shared Resource predicate");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_should_emit_generic_cleanup_diagnostic(&env_decl_shadow, "shadow_decl_dir", ctx) != 0 {
        os.LogStr("Error: directory shadow records must not emit generic Resource cleanup diagnostics");
        os.Exit(1);
    }
    mut shadow_decl_destructor := typechecker.env_open_linear_resource_destructor_name(&env_decl_shadow, "shadow_decl_dir", ctx);
    if std.str_eq(shadow_decl_destructor, "os.CloseDir") == 0 {
        os.LogStr("Error: directory declaration shadow record should carry os.CloseDir destructor identity");
        os.LogStr(shadow_decl_destructor);
        os.Exit(1);
    }

    mut lex_close_shadow: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_close_shadow, "os.CloseDir(shadow_decl_dir)");
    mut parser_close_shadow: parser.Parser[ctx];
    parser.init_parser(&parser_close_shadow, &lex_close_shadow, ctx);
    mut close_shadow_expr := parser.parse_expression(&parser_close_shadow, 1, ctx);
    typechecker.check_expression(close_shadow_expr, &env_decl_shadow, scope_decl_shadow, ctx);

    if env_decl_shadow.open_directories.Get("shadow_decl_dir").Ok {
        os.LogStr("Error: os.CloseDir should still clear legacy open_directories during shadow tracking");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_closed(&env_decl_shadow, "shadow_decl_dir", ctx) != 1 {
        os.LogStr("Error: os.CloseDir should shadow-track closed open_linear_resource state");
        os.Exit(1);
    }
    if env_has_error_containing(&env_decl_shadow, "LinearResourceDoubleClose", ctx) == 1 {
        os.LogStr("Error: os.CloseDir directory shadow close should not also trigger generic Resource destructor-call tracking");
        if len(env_decl_shadow.errors) > 0 {
            os.LogStr(env_decl_shadow.errors[0].message);
        }
        os.Exit(1);
    }
    mut close_shadow_expr_node := ctx[close_shadow_expr];
    typechecker.env_track_resource_destructor_call_if_applicable(&env_decl_shadow, "os.CloseDir", close_shadow_expr_node.Call.arguments, scope_decl_shadow, ctx);
    if env_has_error_containing(&env_decl_shadow, "LinearResourceDoubleClose", ctx) == 1 {
        os.LogStr("Error: direct generic destructor tracking helper should ignore os.CloseDir directory shadows");
        if len(env_decl_shadow.errors) > 0 {
            os.LogStr(env_decl_shadow.errors[0].message);
        }
        os.Exit(1);
    }

    mut env_manual_shadow := typechecker.env_new(ctx);
    env_manual_shadow.current_prefix = "main__";
    if typechecker.env_shadow_track_open_directory_resource(&env_manual_shadow, "manual_shadow_dir", "os_Dir_ctx", ctx) != 1 {
        os.LogStr("Error: manual directory shadow helper should register open_linear_resources record");
        os.Exit(1);
    }
    if env_manual_shadow.open_directories.Get("manual_shadow_dir").Ok {
        os.LogStr("Error: manual directory shadow helper should not populate legacy open_directories directly");
        os.Exit(1);
    }
    if typechecker.env_shadow_track_closed_directory_resource(&env_manual_shadow, "manual_shadow_dir", ctx) != 1 {
        os.LogStr("Error: manual directory close shadow helper should mark tracked directory closed");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_closed(&env_manual_shadow, "manual_shadow_dir", ctx) != 1 {
        os.LogStr("Error: manual directory shadow close helper did not persist closed state");
        os.Exit(1);
    }

    mut env_cleanup_shadow := typechecker.env_new(ctx);
    env_cleanup_shadow.current_prefix = "main__";
    typechecker.env_shadow_track_open_directory_resource(&env_cleanup_shadow, "cleanup_shadow_dir", "os_Dir_ctx", ctx);
    typechecker.env_validate_linear_resource_scope_exit_cleanup(&env_cleanup_shadow, span_dir_shadow, ctx);
    if env_has_error_containing(&env_cleanup_shadow, "LinearResourceMissingCleanup", ctx) == 1 {
        os.LogStr("Error: directory shadow tracking must not emit generic Resource cleanup diagnostics");
        if len(env_cleanup_shadow.errors) > 0 {
            os.LogStr(env_cleanup_shadow.errors[0].message);
        }
        os.Exit(1);
    }

    os.LogStr("SUCCESS: directory operations shadow-track into open_linear_resources!");
}
