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

    mut span_legacy_dirs: token.Span;
    mut dir_type_legacy_dirs := typechecker.make_type_struct("os_Dir_ctx", "ctx", ctx);

    mut env_move_open_dir := typechecker.env_new(ctx);
    env_move_open_dir.current_prefix = "main__";
    mut scope_move_open_dir := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.scope_insert(scope_move_open_dir, "legacy_move_dir", dir_type_legacy_dirs, ctx);
    env_move_open_dir.variable_types.Insert("legacy_move_dir", dir_type_legacy_dirs);
    env_move_open_dir.open_directories.Insert("legacy_move_dir", 1);

    mut lex_move_open_dir: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_move_open_dir, "move legacy_move_dir");
    mut parser_move_open_dir: parser.Parser[ctx];
    parser.init_parser(&parser_move_open_dir, &lex_move_open_dir, ctx);
    mut expr_move_open_dir := parser.parse_expression(&parser_move_open_dir, 1, ctx);
    typechecker.check_expression(expr_move_open_dir, &env_move_open_dir, scope_move_open_dir, ctx);

    if env_has_error_containing(&env_move_open_dir, "Directory resource variable 'legacy_move_dir' cannot be moved while open", ctx) != 1 {
        os.LogStr("Error: legacy open_directories move-open-directory diagnostic drifted");
        if len(env_move_open_dir.errors) > 0 {
            os.LogStr(env_move_open_dir.errors[0].message);
        }
        os.Exit(1);
    }
    if env_move_open_dir.open_directories.Get("legacy_move_dir").Ok == 0 {
        os.LogStr("Error: rejected move of open directory should leave legacy open_directories entry intact");
        os.Exit(1);
    }

    mut env_close_open_dir := typechecker.env_new(ctx);
    env_close_open_dir.current_prefix = "main__";
    mut scope_close_open_dir := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.scope_insert(scope_close_open_dir, "legacy_close_dir", dir_type_legacy_dirs, ctx);
    env_close_open_dir.variable_types.Insert("legacy_close_dir", dir_type_legacy_dirs);
    env_close_open_dir.open_directories.Insert("legacy_close_dir", 1);

    mut lex_close_open_dir: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_close_open_dir, "os.CloseDir(legacy_close_dir)");
    mut parser_close_open_dir: parser.Parser[ctx];
    parser.init_parser(&parser_close_open_dir, &lex_close_open_dir, ctx);
    mut expr_close_open_dir := parser.parse_expression(&parser_close_open_dir, 1, ctx);
    typechecker.check_expression(expr_close_open_dir, &env_close_open_dir, scope_close_open_dir, ctx);

    if env_close_open_dir.open_directories.Get("legacy_close_dir").Ok {
        os.LogStr("Error: legacy os.CloseDir should clear open_directories entry");
        os.Exit(1);
    }

    mut env_leak_function := typechecker.env_new(ctx);
    env_leak_function.current_prefix = "main__";
    mut scope_leak_function := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut dir_type_idx_leak_function: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(dir_type_idx_leak_function, dir_type_legacy_dirs);

    mut decl_leak_function: ast.Statement[ctx];
    unsafe {
        decl_leak_function.tag = 4; // VarDecl
        decl_leak_function.VarDecl.name = "legacy_leak_dir";
        decl_leak_function.VarDecl.is_mut = 1;
        decl_leak_function.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        decl_leak_function.VarDecl.var_type = dir_type_idx_leak_function;
        decl_leak_function.VarDecl.span = span_legacy_dirs;
    }

    mut body_statements_leak_function: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
    body_statements_leak_function.Push(decl_leak_function);
    mut body_statements_idx_leak_function: Index[std.Vector[ast.Statement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_statements_idx_leak_function, body_statements_leak_function);

    mut body_leak_function: ast.BlockStatement[ctx];
    body_leak_function.statements = body_statements_idx_leak_function;
    body_leak_function.span = span_legacy_dirs;
    mut body_idx_leak_function: Index[ast.BlockStatement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_idx_leak_function, body_leak_function);

    mut params_leak_function: std.Vector[ast.Parameter[ctx], ctx] := std.VectorNew(ctx);
    mut params_idx_leak_function: Index[std.Vector[ast.Parameter[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(params_idx_leak_function, params_leak_function);

    mut return_type_leak_function: ast.Type[ctx];
    unsafe {
        return_type_leak_function.tag = 3; // Void
    }
    mut return_type_idx_leak_function: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(return_type_idx_leak_function, return_type_leak_function);

    mut function_stmt_leak_function: ast.Statement[ctx];
    unsafe {
        function_stmt_leak_function.tag = 3; // FunctionDecl
        function_stmt_leak_function.FunctionDecl.name = "legacy_open_directories_leak_freeze";
        function_stmt_leak_function.FunctionDecl.is_unsafe = 0;
        function_stmt_leak_function.FunctionDecl.is_extern = 0;
        function_stmt_leak_function.FunctionDecl.extern_symbol_name = "";
        function_stmt_leak_function.FunctionDecl.extern_abi = "C";
        function_stmt_leak_function.FunctionDecl.requires_unsafe_call = 0;
        function_stmt_leak_function.FunctionDecl.requires_layout_metadata = 0;
        function_stmt_leak_function.FunctionDecl.requires_sandbox_arena = 0;
        function_stmt_leak_function.FunctionDecl.params = params_idx_leak_function;
        function_stmt_leak_function.FunctionDecl.return_type = return_type_idx_leak_function;
        function_stmt_leak_function.FunctionDecl.body = body_idx_leak_function;
        function_stmt_leak_function.FunctionDecl.span = span_legacy_dirs;
    }
    mut function_stmt_idx_leak_function: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(function_stmt_idx_leak_function, function_stmt_leak_function);

    typechecker.check_statement(function_stmt_idx_leak_function, &env_leak_function, scope_leak_function, ctx);

    if env_has_error_containing(&env_leak_function, "must be cleanly closed with os.CloseDir before leaving local scope", ctx) != 1 {
        os.LogStr("Error: legacy open_directories function-exit leak diagnostic drifted");
        if len(env_leak_function.errors) > 0 {
            os.LogStr(env_leak_function.errors[0].message);
        }
        os.Exit(1);
    }
    if env_has_error_containing(&env_leak_function, "legacy_leak_dir", ctx) != 1 {
        os.LogStr("Error: legacy open_directories leak diagnostic should name leaked directory");
        if len(env_leak_function.errors) > 0 {
            os.LogStr(env_leak_function.errors[0].message);
        }
        os.Exit(1);
    }

    mut env_clean_function := typechecker.env_new(ctx);
    env_clean_function.current_prefix = "main__";
    mut scope_clean_function := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut dir_type_idx_clean_function: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(dir_type_idx_clean_function, dir_type_legacy_dirs);

    mut decl_clean_function: ast.Statement[ctx];
    unsafe {
        decl_clean_function.tag = 4; // VarDecl
        decl_clean_function.VarDecl.name = "legacy_clean_dir";
        decl_clean_function.VarDecl.is_mut = 1;
        decl_clean_function.VarDecl.value = empty[Index[ast.Expression[ctx], ctx]];
        decl_clean_function.VarDecl.var_type = dir_type_idx_clean_function;
        decl_clean_function.VarDecl.span = span_legacy_dirs;
    }

    mut lex_close_stmt_clean_function: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_close_stmt_clean_function, "os.CloseDir(legacy_clean_dir);");
    mut parser_close_stmt_clean_function: parser.Parser[ctx];
    parser.init_parser(&parser_close_stmt_clean_function, &lex_close_stmt_clean_function, ctx);
    mut close_stmt_clean_function := parser.parse_statement(&parser_close_stmt_clean_function, ctx);

    mut body_statements_clean_function: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
    body_statements_clean_function.Push(decl_clean_function);
    body_statements_clean_function.Push(ctx[close_stmt_clean_function]);
    mut body_statements_idx_clean_function: Index[std.Vector[ast.Statement[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_statements_idx_clean_function, body_statements_clean_function);

    mut body_clean_function: ast.BlockStatement[ctx];
    body_clean_function.statements = body_statements_idx_clean_function;
    body_clean_function.span = span_legacy_dirs;
    mut body_idx_clean_function: Index[ast.BlockStatement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(body_idx_clean_function, body_clean_function);

    mut params_clean_function: std.Vector[ast.Parameter[ctx], ctx] := std.VectorNew(ctx);
    mut params_idx_clean_function: Index[std.Vector[ast.Parameter[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(params_idx_clean_function, params_clean_function);

    mut return_type_clean_function: ast.Type[ctx];
    unsafe {
        return_type_clean_function.tag = 3; // Void
    }
    mut return_type_idx_clean_function: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(return_type_idx_clean_function, return_type_clean_function);

    mut function_stmt_clean_function: ast.Statement[ctx];
    unsafe {
        function_stmt_clean_function.tag = 3; // FunctionDecl
        function_stmt_clean_function.FunctionDecl.name = "legacy_open_directories_clean_freeze";
        function_stmt_clean_function.FunctionDecl.is_unsafe = 0;
        function_stmt_clean_function.FunctionDecl.is_extern = 0;
        function_stmt_clean_function.FunctionDecl.extern_symbol_name = "";
        function_stmt_clean_function.FunctionDecl.extern_abi = "C";
        function_stmt_clean_function.FunctionDecl.requires_unsafe_call = 0;
        function_stmt_clean_function.FunctionDecl.requires_layout_metadata = 0;
        function_stmt_clean_function.FunctionDecl.requires_sandbox_arena = 0;
        function_stmt_clean_function.FunctionDecl.params = params_idx_clean_function;
        function_stmt_clean_function.FunctionDecl.return_type = return_type_idx_clean_function;
        function_stmt_clean_function.FunctionDecl.body = body_idx_clean_function;
        function_stmt_clean_function.FunctionDecl.span = span_legacy_dirs;
    }
    mut function_stmt_idx_clean_function: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(function_stmt_idx_clean_function, function_stmt_clean_function);

    typechecker.check_statement(function_stmt_idx_clean_function, &env_clean_function, scope_clean_function, ctx);

    if env_has_error_containing(&env_clean_function, "must be cleanly closed with os.CloseDir before leaving local scope", ctx) == 1 {
        os.LogStr("Error: legacy os.CloseDir-cleaned directory should not report function-exit leak");
        if len(env_clean_function.errors) > 0 {
            os.LogStr(env_clean_function.errors[0].message);
        }
        os.Exit(1);
    }

    os.LogStr("SUCCESS: legacy open_directories behavior frozen!");
}