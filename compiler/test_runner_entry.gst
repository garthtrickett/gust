import "token.gst" as token;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "ast.gst" as ast;
import "errors.gst" as errors;
import "typechecker.gst" as typechecker;
import "resolver.gst" as resolver;
import "codegen.gst" as codegen;

type FileParserError[ctx] struct {
    file_path: str,
    err: errors.CompilerError[ctx]
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut args := os.Args(ctx);
    if len(args) < 2 {
        os.LogStr("Usage: test_runner_entry <file_path>");
        os.Exit(1);
    }
    mut file_path := args[1];

    // 1. Initialize Dependency Graph & Resolve Imports
    mut graph: std.Graph[str, ctx] := std.GraphNew(ctx);
    mut path_to_node: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);

    resolver.resolve_imports_recursive(file_path, &graph, &path_to_node, ctx);

    // 2. Resolve Topological Sorting Compilation Order
    mut order := resolver.resolve_topological_sort(file_path, &graph, &path_to_node, ctx);
    if len(order) == 0 {
        os.LogStr("Error: No files found or resolved");
        os.Exit(1);
    }

    // 3. Initialize Global Type Environment
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    // 4. Parse all programs in Topological Order & Pre-register Types
    mut programs: std.Vector[ast.Program[ctx], ctx] := std.VectorNew(ctx);
    mut module_prefixes: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut accumulated_parser_errors: std.Vector[FileParserError[ctx], ctx] := std.VectorNew(ctx);

    mut i := 0;
    while i < len(order) {
        mut path := order[i];
        mut source := os.ReadFile(ctx, path);
        if len(source) == 0 {
            mut msg := std.Concat("Error: empty file or failed to read: ", path);
            os.LogStr(msg);
            os.Exit(1);
        }

        mut l: lexer.Lexer[ctx];
        lexer.init_lexer(&l, source);

        mut p: parser.Parser[ctx];
        parser.init_parser(&p, &l, ctx);

        mut prog := parser.parse_program(&p, ctx);
        if len(p.errors) > 0 {
            mut err_idx := 0;
            while err_idx < len(p.errors) {
                mut f_err: FileParserError[ctx];
                f_err.file_path = path;
                f_err.err = p.errors[err_idx];
                accumulated_parser_errors.Push(f_err);
                err_idx = err_idx + 1;
            }
        }

        programs.Push(prog);

        mut stem := typechecker.typechecker_get_file_stem(path, ctx);
        mut is_entry := std.str_eq(path, file_path);
        mut prefix := "";
        if is_entry == 0 {
            // Secure prefix string view in long-lived Arena to prevent scratchpad corruption (Step 3)
            // The prefix string must be anchored in the long-lived Arena (ctx) to prevent transient
            // scratchpad corruption before it is assigned to env.current_prefix.
            prefix = std.Clone(ctx, std.Concat(stem, "__"));
        }
        module_prefixes.Push(prefix);

        // Set current prefix and pre-register statements
        env.current_prefix = prefix;
        env.current_file = path;
        unsafe {
            mut statements_vec := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
            mut k := 0;
            while k < len(*statements_vec) {
                typechecker.env_pre_register_statement(&env, (*statements_vec)[k], ctx);
                k = k + 1;
            }
        }

        i = i + 1;
    }

    if len(accumulated_parser_errors) > 0 {
        mut err_idx := 0;
        while err_idx < len(accumulated_parser_errors) {
            mut f_err := accumulated_parser_errors[err_idx];
            mut msg := std.Format("ParserError in %s at line %d:%d: %s", 
                f_err.file_path, 
                f_err.err.span.start.line, 
                f_err.err.span.start.column, 
                f_err.err.message);
            os.LogStr(msg);
            err_idx = err_idx + 1;
        }
        os.Exit(1);
    }

    // 5. Typecheck all programs in Topological Order
    typechecker.env_synthesize_is_valid_helpers(&env, ctx);

    mut j := 0;
    while j < len(order) {
        mut prog := programs[j];
        mut prefix := module_prefixes[j];

        env.current_prefix = prefix;
        env.current_file = order[j];

        unsafe {
            mut statements_vec := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
            mut k := 0;
            while k < len(*statements_vec) {
                mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx[stmt_idx] = (*statements_vec)[k];
                typechecker.check_statement(stmt_idx, &env, scope, ctx);
                k = k + 1;
            }
        }

        j = j + 1;
    }

    if len(env.errors) > 0 {
        mut k := 0;
        while k < len(env.errors) {
            os.LogStr(env.errors[k].message); // Should be this but this errors
            k = k + 1;
        }
        os.Exit(1);
    }

    // Print full Type Environment dump for bootstrapping diagnostics
    os.LogStr("👁️ === BOOTSTRAP TYPE DUMP ===");
    mut serialized := typechecker.typechecker_serialize_type_environment(&env, ctx);
    mut lines := std.str_split(serialized, "\n", ctx);
    mut l_idx := 0;
    while l_idx < len(lines) {
        mut line := lines[l_idx];
        if len(line) > 0 {
            mut log_line := std.Concat("👁️ ", line);
            os.LogStr(log_line);
        }
        l_idx = l_idx + 1;
    }
    os.LogStr("👁️ ===========================");

    // Print all nested resolved types
    os.LogStr("👁️ === BOOTSTRAP RESOLVED TYPES ===");
    mut entry_source_code := os.ReadFile(ctx, file_path);
    mut r_idx := 0;
    while r_idx < len(env.resolved_types_nested) {
        mut entry := env.resolved_types_nested[r_idx];
        mut log_pfx := std.Concat("👁️ Prefix: ", entry.prefix);
        os.LogStr(log_pfx);
        
        mut t_idx := 0;
            while t_idx < len(entry.types) {
                mut t_entry := entry.types[t_idx];
                mut start_str := std.FormatInt(t_entry.start_offset);
                mut end_str := std.FormatInt(t_entry.end_offset);
                mut type_str := ast.serialize_type(t_entry.val_type, ctx);

                mut expr_text := "";
                if std.str_eq(entry.prefix, "") == 1 {
                    if t_entry.start_offset >= 0 && t_entry.end_offset <= len(entry_source_code) && t_entry.start_offset < t_entry.end_offset {
                        expr_text = std.str_slice(entry_source_code, t_entry.start_offset, t_entry.end_offset);
                    }
                }

                // Sanitize expr_text to remove newlines and keep the log strictly single-line
                mut clean_expr_text := "";
                mut char_idx := 0;
                while char_idx < len(expr_text) {
                    mut b := std.str_byte_at(expr_text, char_idx);
                    if b == 10 || b == 13 { // '\n' or '\r'
                        clean_expr_text = std.Concat(clean_expr_text, " ");
                    } else {
                        clean_expr_text = std.Concat(clean_expr_text, std.str_slice(expr_text, char_idx, char_idx + 1));
                    }
                    char_idx = char_idx + 1;
                }

                mut log_line := std.Concat("👁   Span ", start_str);
                log_line = std.Concat(log_line, "..");
                log_line = std.Concat(log_line, end_str);
                log_line = std.Concat(log_line, " ('");
                log_line = std.Concat(log_line, clean_expr_text);
                log_line = std.Concat(log_line, "') -> ");
                log_line = std.Concat(log_line, type_str);
                os.LogStr(log_line);

                if std.str_find(expr_text, "env.errors") != 0 - 1 {
                    mut log_match := std.Concat("🎯 MATCH env.errors: '", clean_expr_text);
                    log_match = std.Concat(log_match, "'");
                    os.LogStr(log_match);
                }
            
            t_idx = t_idx + 1;
        }
        r_idx = r_idx + 1;
    }
    os.LogStr("👁️ =================================");

    // Reset current_prefix to entry module for main call matching
    env.current_prefix = "";

    // 7. Generate Code
        mut c_code := codegen.codegen_generate(programs, module_prefixes, &env, ctx);
        os.LogStr(c_code);
}
