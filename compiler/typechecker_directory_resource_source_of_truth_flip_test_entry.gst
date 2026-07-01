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

    mut span_source_flip: token.Span;
    mut dir_type_source_flip := typechecker.make_type_struct("os_Dir_ctx", "ctx", ctx);

    mut env_resource_only_move := typechecker.env_new(ctx);
    env_resource_only_move.current_prefix = "main__";
    mut scope_resource_only_move := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.scope_insert(scope_resource_only_move, "resource_only_move_dir", dir_type_source_flip, ctx);
    env_resource_only_move.variable_types.Insert("resource_only_move_dir", dir_type_source_flip);
    typechecker.env_shadow_track_open_directory_resource(&env_resource_only_move, "resource_only_move_dir", "os_Dir_ctx", ctx);

    if env_resource_only_move.open_directories.Get("resource_only_move_dir").Ok {
        os.LogStr("Error: Resource-only directory source-of-truth fixture should not need open_directories shim state");
        os.Exit(1);
    }

    mut lex_resource_only_move: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_resource_only_move, "move resource_only_move_dir");
    mut parser_resource_only_move: parser.Parser[ctx];
    parser.init_parser(&parser_resource_only_move, &lex_resource_only_move, ctx);
    mut expr_resource_only_move := parser.parse_expression(&parser_resource_only_move, 1, ctx);
    typechecker.check_expression(expr_resource_only_move, &env_resource_only_move, scope_resource_only_move, ctx);

    if env_has_error_containing(&env_resource_only_move, "Directory resource variable 'resource_only_move_dir' cannot be moved while open", ctx) != 1 {
        os.LogStr("Error: directory move-open diagnostic should read Resource source of truth without open_directories shim state");
        if len(env_resource_only_move.errors) > 0 {
            os.LogStr(env_resource_only_move.errors[0].message);
        }
        os.Exit(1);
    }

    mut env_legacy_shim_sync := typechecker.env_new(ctx);
    env_legacy_shim_sync.current_prefix = "main__";
    env_legacy_shim_sync.variable_types.Insert("legacy_shim_sync_dir", dir_type_source_flip);
    env_legacy_shim_sync.open_directories.Insert("legacy_shim_sync_dir", 1);

    if typechecker.env_open_linear_resource_is_directory_shadow(&env_legacy_shim_sync, "legacy_shim_sync_dir", ctx) != 0 {
        os.LogStr("Error: legacy shim sync fixture should start without Resource directory state");
        os.Exit(1);
    }
    if typechecker.env_open_directory_resource_requires_cleanup(&env_legacy_shim_sync, "legacy_shim_sync_dir", ctx) != 1 {
        os.LogStr("Error: open_directories compatibility shim should sync into Resource cleanup source of truth");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_directory_shadow(&env_legacy_shim_sync, "legacy_shim_sync_dir", ctx) != 1 {
        os.LogStr("Error: open_directories compatibility shim should materialize Resource directory shadow state");
        os.Exit(1);
    }

    mut env_legacy_shim_close := typechecker.env_new(ctx);
    env_legacy_shim_close.current_prefix = "main__";
    mut scope_legacy_shim_close := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.scope_insert(scope_legacy_shim_close, "legacy_shim_close_dir", dir_type_source_flip, ctx);
    env_legacy_shim_close.variable_types.Insert("legacy_shim_close_dir", dir_type_source_flip);
    env_legacy_shim_close.open_directories.Insert("legacy_shim_close_dir", 1);

    mut lex_legacy_shim_close: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_legacy_shim_close, "os.CloseDir(legacy_shim_close_dir)");
    mut parser_legacy_shim_close: parser.Parser[ctx];
    parser.init_parser(&parser_legacy_shim_close, &lex_legacy_shim_close, ctx);
    mut expr_legacy_shim_close := parser.parse_expression(&parser_legacy_shim_close, 1, ctx);
    typechecker.check_expression(expr_legacy_shim_close, &env_legacy_shim_close, scope_legacy_shim_close, ctx);

    if env_legacy_shim_close.open_directories.Get("legacy_shim_close_dir").Ok {
        os.LogStr("Error: open_directories compatibility shim should still clear after CloseDir");
        os.Exit(1);
    }
    if typechecker.env_open_linear_resource_is_closed(&env_legacy_shim_close, "legacy_shim_close_dir", ctx) != 1 {
        os.LogStr("Error: CloseDir should sync legacy shim state into Resource source of truth before closing");
        os.Exit(1);
    }

    mut env_decl_shim_mirror := typechecker.env_new(ctx);
    env_decl_shim_mirror.current_prefix = "main__";
    mut scope_decl_shim_mirror := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut dir_type_idx_decl_shim_mirror: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(dir_type_idx_decl_shim_mirror, dir_type_source_flip);

    mut decl_shim_mirror: ast.Statement[ctx];
    unsafe {
        decl_shim_mirror.tag = 4; // VarDecl
        decl_shim_mirror.VarDecl.name = "decl_shim_mirror_dir";
        decl_shim_mirror.VarDecl.is_mut = 1;
        decl_shim_mirror.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        decl_shim_mirror.VarDecl.var_type = dir_type_idx_decl_shim_mirror;
        decl_shim_mirror.VarDecl.span = span_source_flip;
    }
    mut decl_shim_mirror_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(decl_shim_mirror_idx, decl_shim_mirror);
    typechecker.check_statement(decl_shim_mirror_idx, &env_decl_shim_mirror, scope_decl_shim_mirror, ctx);

    if typechecker.env_open_directory_resource_requires_cleanup(&env_decl_shim_mirror, "decl_shim_mirror_dir", ctx) != 1 {
        os.LogStr("Error: real directory declaration should use Resource state as cleanup source of truth");
        os.Exit(1);
    }
    if env_decl_shim_mirror.open_directories.Get("decl_shim_mirror_dir").Ok == false {
        os.LogStr("Error: real directory declaration should still mirror into open_directories compatibility shim");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: directory Resource source of truth flipped with open_directories compatibility shim!");
}