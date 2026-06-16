import "token.gst" as token;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "ast.gst" as ast;
import "errors.gst" as errors;
import "typechecker.gst" as typechecker;
import "resolver.gst" as resolver;
import "codegen.gst" as codegen;

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
                os.LogStr("ParserError in file: ");
                os.LogStr(path);
                mut err_idx := 0;
                while err_idx < len(p.errors) {
                    mut err := p.errors[err_idx];
                    os.LogStr(err.message);
                    os.LogInt(err.span.start.line);
                    os.LogInt(err.span.start.column);
                    err_idx = err_idx + 1;
                }
                os.Exit(1);
            }

        programs.Push(prog);

        mut stem := typechecker.typechecker_get_file_stem(path, ctx);
        mut is_entry := std.str_eq(path, file_path);
        mut prefix := "";
        if is_entry == 0 {
            prefix = std.Clone(ctx, std.Concat(stem, "__"));
        }
        module_prefixes.Push(prefix);

        // Set current prefix and pre-register statements
        env.current_prefix = prefix;
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

    // 5. Typecheck all programs in Topological Order
    mut j := 0;
    while j < len(order) {
        mut prog := programs[j];
        mut prefix := module_prefixes[j];

        env.current_prefix = prefix;

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
            os.LogStr(env.errors[k].message);
            k = k + 1;
        }
        os.Exit(1);
    }

    // 6. Consolidate all statements into a single unified ast.Program for codegen
    mut unified_statements: std.Vector[ast.Statement[ctx], ctx] := std.VectorNew(ctx);
    mut m := 0;
    while m < len(order) {
        mut prog := programs[m];
        unsafe {
            mut statements_vec := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
            mut n := 0;
            while n < len(*statements_vec) {
                unified_statements.Push((*statements_vec)[n]);
                n = n + 1;
            }
        }
        m = m + 1;
    }

    mut unified_prog: ast.Program[ctx];
    unified_prog.statements = os.ArenaAlloc(ctx);
    unsafe {
        mut dest_statements := &ctx[unified_prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
        *dest_statements = unified_statements;
    }

    // Reset current_prefix to entry module for main call matching
    env.current_prefix = "";

    // 7. Generate Code
    mut c_code := codegen.codegen_generate(&unified_prog, &env, ctx);
    os.LogStr(c_code);
}
