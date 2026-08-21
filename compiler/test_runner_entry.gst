import "token.gst" as token;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "ast.gst" as ast;
import "errors.gst" as errors;
import "typechecker.gst" as typechecker;
import "resolver.gst" as resolver;
import "codegen.gst" as codegen;
import "mir_native_backend_source_route.gst" as native_source_route;

type CompilerBackendSelection enum {
    MirToC,
    CraneliftExperimental
}

type CompilerInvocation[ctx] struct {
    backend: CompilerBackendSelection,
    source_path: str,
    output_path: str,
    backend_was_explicit: int,
    output_was_explicit: int
}

func compiler_is_help_invocation(args: std.Vector[str, ctx], ctx: &Arena) int {
    if len(args) != 2 {
        return 0;
    }
    if std.str_eq(args[1], "--help") == 1 ||
       std.str_eq(args[1], "-h") == 1
    {
        return 1;
    }
    return 0;
}

func compiler_print_help() {
    os.LogStr("Usage:");
    os.LogStr("  gust <source.gst>");
    os.LogStr("  gust --backend mir-to-c <source.gst>");
    os.LogStr("  gust --backend cranelift -o <output> <source.gst>");
    os.LogStr("");
    os.LogStr("Backends:");
    os.LogStr("  mir-to-c   Emit C source to stdout (default).");
    os.LogStr("  cranelift  Compile a supported source cohort to one native executable (experimental).");
    os.LogStr("");
    os.LogStr("Options:");
    os.LogStr("  --backend <mir-to-c|cranelift>  Select the backend explicitly.");
    os.LogStr("  -o <output>                     Required only by the cranelift backend.");
    os.LogStr("  -h, --help                      Show this help and exit.");
    os.LogStr("");
    os.LogStr("Native backend driver:");
    os.LogStr("  Set GUST_NATIVE_BACKEND_DRIVER to an absolute executable path, or install");
    os.LogStr("  gust-native-backend next to gust. There is no PATH search, auto-build, or");
    os.LogStr("  fallback to MIR-to-C.");
}

func compiler_argument_starts_with(value: str, prefix: str) int {
    mut value_len := len(value);
    mut prefix_len := len(prefix);
    if value_len < prefix_len {
        return 0;
    }
    mut candidate := std.str_slice(value, 0, prefix_len);
    if std.str_eq(candidate, prefix) == 1 {
        return 1;
    }
    return 0;
}

func compiler_invocation_fail(message: str) {
    os.LogStr(std.Concat("Compiler invocation error: ", message));
    os.Exit(1);
}

func compiler_parse_invocation(args: std.Vector[str, ctx], ctx: &Arena) CompilerInvocation[ctx] {
    mut invocation: CompilerInvocation[ctx];
    unsafe {
        invocation.backend.tag = 0; // MirToC
    }
    invocation.source_path = "";
    invocation.output_path = "";
    invocation.backend_was_explicit = 0;
    invocation.output_was_explicit = 0;

    mut i := 1;
    while i < len(args) {
        mut arg := args[i];

        if std.str_eq(arg, "--backend") == 1 {
            if invocation.backend_was_explicit == 1 {
                compiler_invocation_fail("duplicate --backend option");
            }
            if i + 1 >= len(args) {
                compiler_invocation_fail("missing value after --backend");
            }

            mut backend_name := args[i + 1];
            if std.str_eq(backend_name, "mir-to-c") == 1 {
                unsafe {
                    invocation.backend.tag = 0; // MirToC
                }
            } else if std.str_eq(backend_name, "cranelift") == 1 {
                unsafe {
                    invocation.backend.tag = 1; // CraneliftExperimental
                }
            } else {
                compiler_invocation_fail(std.Concat("unknown backend: ", backend_name));
            }

            invocation.backend_was_explicit = 1;
            i = i + 2;
        } else if std.str_eq(arg, "-o") == 1 {
            if invocation.output_was_explicit == 1 {
                compiler_invocation_fail("duplicate -o option");
            }
            if i + 1 >= len(args) {
                compiler_invocation_fail("missing value after -o");
            }

            mut output_path := args[i + 1];
            if compiler_argument_starts_with(output_path, "-") == 1 {
                compiler_invocation_fail("missing value after -o");
            }

            invocation.output_path = output_path;
            invocation.output_was_explicit = 1;
            i = i + 2;
        } else {
            if compiler_argument_starts_with(arg, "-") == 1 {
                compiler_invocation_fail(std.Concat("unknown option: ", arg));
            }
            if std.str_eq(invocation.source_path, "") == 0 {
                compiler_invocation_fail("multiple source paths are not supported");
            }

            invocation.source_path = arg;
            i = i + 1;
        }
    }

    if std.str_eq(invocation.source_path, "") == 1 {
        compiler_invocation_fail("expected exactly one source path");
    }

    if invocation.backend.tag == 0 && invocation.output_was_explicit == 1 {
        compiler_invocation_fail("the MIR-to-C backend does not accept -o");
    }

    if invocation.backend.tag == 1 && invocation.output_was_explicit == 0 {
        compiler_invocation_fail("the experimental backend requires exactly one -o <output> value");
    }

    return invocation;
}

type FileParserError[ctx] struct {
    file_path: str,
    err: errors.CompilerError[ctx]
}

func print_error_with_frame(err: errors.CompilerError[ctx], ctx: &Arena) {
    mut msg := "";
    if std.str_eq(err.file_path, "") == 1 {
        msg = std.Format("TypeError at line %d:%d: %s", err.span.start.line, err.span.start.column, err.message);
    } else {
        msg = std.Format("TypeError in %s at line %d:%d: %s", err.file_path, err.span.start.line, err.span.start.column, err.message);
    }
    os.LogStr(msg);

    if std.str_eq(err.file_path, "") == 0 {
        mut content := os.ReadFile(ctx, err.file_path);
        if len(content) > 0 {
            mut lines := std.str_split(content, "\n", ctx);
            mut target_line := err.span.start.line;
            mut start_line := target_line - 3;
            if start_line < 1 {
                start_line = 1;
            }
            mut end_line := target_line + 2;
            if end_line > len(lines) {
                end_line = len(lines);
            }

            mut idx := start_line - 1;
            while idx < end_line {
                mut line := lines[idx];
                mut num_str := std.FormatInt(idx + 1);
                
                mut pad := "";
                if idx + 1 < 10 {
                    pad = "   ";
                } else if idx + 1 < 100 {
                    pad = "  ";
                } else if idx + 1 < 1000 {
                    pad = " ";
                }
                
                mut formatted_line := std.Format("%s%s | %s", pad, num_str, line);
                os.LogStr(formatted_line);

                if idx + 1 == target_line {
                    mut caret_pad := "";
                    mut c_idx := 0;
                    mut target_col := err.span.start.column;
                    while c_idx < target_col - 1 {
                        caret_pad = std.Concat(caret_pad, " ");
                        c_idx = c_idx + 1;
                    }
                    
                    mut space_pad := "";
                    if idx + 1 < 10 {
                        space_pad = "   ";
                    } else if idx + 1 < 100 {
                        space_pad = "  ";
                    } else if idx + 1 < 1000 {
                        space_pad = " ";
                    }
                    
                    mut len_num_str := len(num_str);
                    mut caret_line := std.Concat(space_pad, "");
                    mut spaces_count := 0;
                    while spaces_count < len_num_str {
                        caret_line = std.Concat(caret_line, " ");
                        spaces_count = spaces_count + 1;
                    }
                    caret_line = std.Concat(caret_line, " | ");
                    caret_line = std.Concat(caret_line, caret_pad);
                    caret_line = std.Concat(caret_line, "^");
                    os.LogStr(caret_line);
                }
                idx = idx + 1;
            }
            os.LogStr("");
        }
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut args := os.Args(ctx);
    if compiler_is_help_invocation(args, ctx) == 1 {
        compiler_print_help();
        os.Exit(0);
    }

    mut invocation := compiler_parse_invocation(args, ctx);
    mut file_path := invocation.source_path;

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

    // Discover every generic template before full pre-registration. This makes
    // same-local-name templates structurally ambiguous from the first module,
    // independent of resolver order.
    mut discovery_idx := 0;
    while discovery_idx < len(programs) {
        env.current_prefix = module_prefixes[discovery_idx];
        env.current_file = order[discovery_idx];
        mut discovery_program := programs[discovery_idx];
        mut discovery_statements: std.Vector[ast.Statement[ctx], ctx] := ctx[discovery_program.statements];
        mut discovery_stmt_idx := 0;
        while discovery_stmt_idx < len(discovery_statements) {
            typechecker.env_pre_register_template_statement(&env, discovery_statements[discovery_stmt_idx], ctx);
            discovery_stmt_idx = discovery_stmt_idx + 1;
        }
        discovery_idx = discovery_idx + 1;
    }

    mut preregister_idx := 0;
    while preregister_idx < len(programs) {
        env.current_prefix = module_prefixes[preregister_idx];
        env.current_file = order[preregister_idx];
        mut preregister_program := programs[preregister_idx];
        mut preregister_statements: std.Vector[ast.Statement[ctx], ctx] := ctx[preregister_program.statements];
        mut preregister_stmt_idx := 0;
        while preregister_stmt_idx < len(preregister_statements) {
            typechecker.env_pre_register_statement(&env, preregister_statements[preregister_stmt_idx], ctx);
            preregister_stmt_idx = preregister_stmt_idx + 1;
        }
        preregister_idx = preregister_idx + 1;
    }

    // 5. Typecheck all programs in Topological Order
    typechecker.env_synthesize_is_valid_helpers(&env, ctx);

    mut j := 0;
    while j < len(order) {
        mut prog := programs[j];
        mut prefix := module_prefixes[j];

        env.current_prefix = prefix;
        env.current_file = order[j];

        mut statements_vec_check: std.Vector[ast.Statement[ctx], ctx] := ctx[prog.statements];
        mut k_check := 0;
        while k_check < len(statements_vec_check) {
            mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx.Set(stmt_idx, statements_vec_check[k_check]);
            typechecker.check_statement(stmt_idx, &env, scope, ctx);
            k_check = k_check + 1;
        }

        j = j + 1;
    }

    if len(env.errors) > 0 {
        mut k := 0;
        while k < len(env.errors) {
            mut err := env.errors[k];
            print_error_with_frame(err, ctx);
            k = k + 1;
        }
        os.Exit(1);
    }

    // Reset current_prefix to entry module for main call matching
    env.current_prefix = "";

    // 7. Select the backend only after the shared resolver, parser, and
    // typechecker pipeline has completed. The experimental route accepts only
    // registry-owned generic canonical-MIR entries and never falls back.
    if invocation.backend.tag == 1 {
        mut native_result :=
            native_source_route.mir_native_scalar_source_compile(
                programs,
                order,
                module_prefixes,
                invocation.output_path,
                ctx
            );
        if native_result.status == 0 {
            os.Exit(0);
        }
        os.LogStr(
            native_source_route.mir_native_scalar_source_capability_decision_line(
                native_result,
                ctx
            )
        );
        os.LogStr(
            native_source_route.mir_native_scalar_source_diagnostic_line(
                native_result,
                ctx
            )
        );
        if native_result.status == 2 {
            os.LogStr("Experimental Cranelift backend selection is valid, but the source-level route is not connected yet.");
            os.Exit(1);
        }
        os.LogError(native_result.diagnostic);
        os.Exit(1);
    }

    // Test-only poison used by the semantic route architecture evidence.
    // Normal invocations never set this environment variable.
    if std.str_eq(
        os.GetEnv(ctx, "GUST_TEST_MIR_TO_C_UNAVAILABLE"),
        "1"
    ) == 1 {
        os.LogError(
            "MIR-to-C intentionally unavailable for route architecture evidence."
        );
        os.Exit(1);
    }

    // Default and explicit MIR-to-C selections share this exact codegen path.
    mut c_code := codegen.codegen_generate(programs, module_prefixes, &env, ctx);
    os.LogStr(c_code);
}
