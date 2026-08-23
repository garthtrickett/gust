import "lexer.gst" as lexer;
import "parser.gst" as parser;
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

    mut dir_type_legacy_dirs := typechecker.make_type_struct("os_Dir_ctx", "ctx", ctx);

    // Patch 20.10 retires enforcement reads from open_directories. A direct
    // compatibility-storage write cannot manufacture canonical ownership.
    mut env_legacy_only_move := typechecker.env_new(ctx);
    env_legacy_only_move.current_prefix = "main__";
    mut scope_legacy_only_move := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.scope_insert(scope_legacy_only_move, "legacy_only_move_dir", dir_type_legacy_dirs, ctx);
    env_legacy_only_move.variable_types.Insert("legacy_only_move_dir", dir_type_legacy_dirs);
    env_legacy_only_move.open_directories.Insert("legacy_only_move_dir", 1);

    mut lex_legacy_only_move: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_legacy_only_move, "move legacy_only_move_dir");
    mut parser_legacy_only_move: parser.Parser[ctx];
    parser.init_parser(&parser_legacy_only_move, &lex_legacy_only_move, ctx);
    mut expr_legacy_only_move := parser.parse_expression(&parser_legacy_only_move, 1, ctx);
    typechecker.check_expression(expr_legacy_only_move, &env_legacy_only_move, scope_legacy_only_move, ctx);

    if env_has_error_containing(&env_legacy_only_move, "Directory resource variable 'legacy_only_move_dir' cannot be moved while open", ctx) == 1 {
        os.LogStr("Error: write-only open_directories storage became an enforcement source");
        os.Exit(1);
    }
    if env_legacy_only_move.open_directories.Get("legacy_only_move_dir").Ok == false {
        os.LogStr("Error: an enforcement query mutated write-only open_directories storage");
        os.Exit(1);
    }

    // Compatibility close operations still clear the mirrored storage even
    // when no canonical Resource shadow was established.
    mut env_legacy_only_close := typechecker.env_new(ctx);
    env_legacy_only_close.current_prefix = "main__";
    mut scope_legacy_only_close := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.scope_insert(scope_legacy_only_close, "legacy_only_close_dir", dir_type_legacy_dirs, ctx);
    env_legacy_only_close.variable_types.Insert("legacy_only_close_dir", dir_type_legacy_dirs);
    env_legacy_only_close.open_directories.Insert("legacy_only_close_dir", 1);

    mut lex_legacy_only_close: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_legacy_only_close, "os.CloseDir(legacy_only_close_dir)");
    mut parser_legacy_only_close: parser.Parser[ctx];
    parser.init_parser(&parser_legacy_only_close, &lex_legacy_only_close, ctx);
    mut expr_legacy_only_close := parser.parse_expression(&parser_legacy_only_close, 1, ctx);
    typechecker.check_expression(expr_legacy_only_close, &env_legacy_only_close, scope_legacy_only_close, ctx);

    if env_legacy_only_close.open_directories.Get("legacy_only_close_dir").Ok {
        os.LogStr("Error: compatibility CloseDir should clear write-only open_directories storage");
        os.Exit(1);
    }

    // The canonical Resource shadow remains the only enforcement source.
    mut env_resource_move := typechecker.env_new(ctx);
    env_resource_move.current_prefix = "main__";
    mut scope_resource_move := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.scope_insert(scope_resource_move, "resource_move_dir", dir_type_legacy_dirs, ctx);
    env_resource_move.variable_types.Insert("resource_move_dir", dir_type_legacy_dirs);
    typechecker.env_shadow_track_open_directory_resource(&env_resource_move, "resource_move_dir", "os_Dir_ctx", ctx);

    mut lex_resource_move: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_resource_move, "move resource_move_dir");
    mut parser_resource_move: parser.Parser[ctx];
    parser.init_parser(&parser_resource_move, &lex_resource_move, ctx);
    mut expr_resource_move := parser.parse_expression(&parser_resource_move, 1, ctx);
    typechecker.check_expression(expr_resource_move, &env_resource_move, scope_resource_move, ctx);

    if env_has_error_containing(&env_resource_move, "Directory resource variable 'resource_move_dir' cannot be moved while open", ctx) != 1 {
        os.LogStr("Error: canonical directory Resource move-open diagnostic drifted");
        if len(env_resource_move.errors) > 0 {
            os.LogStr(env_resource_move.errors[0].message);
        }
        os.Exit(1);
    }

    os.LogStr("SUCCESS: open_directories remains write-only compatibility storage!");
}
