import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func parse_expr_call_return_flow(src: str, ctx: &Arena) Index[ast.Expression[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_expression(&p, 1, ctx);
}

func parse_stmt_call_return_flow(src: str, ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_statement(&p, ctx);
}

func register_zero_arg_int_function_call_return_flow(env: *typechecker.TypeEnvironment[ctx], name: str, return_t: ast.Type[ctx], ctx: &Arena) {
    mut sig: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig);
    sig.param_names = std.VectorNew(ctx);
    sig.params = std.VectorNew(ctx);
    sig.return_type = return_t;
    sig.return_origins = typechecker.set_init(ctx);
    sig.is_unsafe = 0;
    typechecker.env_register_function(env, name, sig, ctx);
}

func assert_raw_call_return_flow(prov: typechecker.ExpressionProvenance[ctx], origin: str, label: str, message: str, ctx: &Arena) {
    if typechecker.step51g_expression_provenance_is_raw_derived(prov) != 1 {
        os.LogStr(std.Concat("Error: raw call/return flow did not preserve raw-derived provenance for ", message));
        os.Exit(1);
    }
    if typechecker.set_contains(prov.legacy_origins, origin, ctx) != 1 {
        os.LogStr(std.Concat("Error: raw call/return flow did not preserve legacy origin for ", message));
        os.Exit(1);
    }
    if std.str_eq(label, "") == 0 {
        if typechecker.set_contains(prov.legacy_origins, label, ctx) != 1 {
            os.LogStr(std.Concat("Error: raw call/return flow did not stamp boundary label for ", message));
            os.Exit(1);
        }
    }
}

func assert_sandbox_call_return_flow(prov: typechecker.ExpressionProvenance[ctx], origin: str, label: str, message: str, ctx: &Arena) {
    if typechecker.step51g_expression_provenance_is_sandbox_derived(prov) != 1 {
        os.LogStr(std.Concat("Error: sandbox call/return flow did not preserve sandbox-derived provenance for ", message));
        os.Exit(1);
    }
    if typechecker.set_contains(prov.legacy_origins, origin, ctx) != 1 {
        os.LogStr(std.Concat("Error: sandbox call/return flow did not preserve legacy origin for ", message));
        os.Exit(1);
    }
    if std.str_eq(label, "") == 0 {
        if typechecker.set_contains(prov.legacy_origins, label, ctx) != 1 {
            os.LogStr(std.Concat("Error: sandbox call/return flow did not stamp boundary label for ", message));
            os.Exit(1);
        }
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut t_int := typechecker.make_type_int();

    register_zero_arg_int_function_call_return_flow(&env, "raw_call_return_fn", t_int, ctx);
    mut raw_call_return_fn_prov := typechecker.expression_provenance_raw_derived(t_int, ctx);
    typechecker.set_add(raw_call_return_fn_prov.legacy_origins, "raw_call_return_fn_root", ctx);
    typechecker.env_record_function_return_provenance(&env, "raw_call_return_fn", raw_call_return_fn_prov, ctx);

    mut raw_call_expr := parse_expr_call_return_flow("raw_call_return_fn()", ctx);
    mut raw_call_prov := typechecker.check_expression_with_provenance(raw_call_expr, &env, scope, ctx);
    assert_raw_call_return_flow(raw_call_prov, "raw_call_return_fn_root", "call:raw_call_return_fn", "raw function call", ctx);

    register_zero_arg_int_function_call_return_flow(&env, "sandbox_call_return_fn", t_int, ctx);
    mut sandbox_call_return_fn_prov := typechecker.expression_provenance_sandbox_derived(t_int, ctx);
    typechecker.set_add(sandbox_call_return_fn_prov.legacy_origins, "sandbox_call_return_fn_root", ctx);
    typechecker.env_record_function_return_provenance(&env, "sandbox_call_return_fn", sandbox_call_return_fn_prov, ctx);

    mut sandbox_call_expr := parse_expr_call_return_flow("sandbox_call_return_fn()", ctx);
    mut sandbox_call_prov := typechecker.check_expression_with_provenance(sandbox_call_expr, &env, scope, ctx);
    assert_sandbox_call_return_flow(sandbox_call_prov, "sandbox_call_return_fn_root", "call:sandbox_call_return_fn", "sandbox function call", ctx);

    typechecker.scope_insert(scope, "raw_return_source", t_int, ctx);
    env.variable_types.Insert("raw_return_source", t_int);
    mut raw_return_source_prov := typechecker.expression_provenance_raw_derived(t_int, ctx);
    typechecker.set_add(raw_return_source_prov.legacy_origins, "raw_return_source_root", ctx);
    typechecker.env_record_variable_provenance(&env, "raw_return_source", raw_return_source_prov, ctx);

    typechecker.scope_insert(scope, "sandbox_return_source", t_int, ctx);
    env.variable_types.Insert("sandbox_return_source", t_int);
    mut sandbox_return_source_prov := typechecker.expression_provenance_sandbox_derived(t_int, ctx);
    typechecker.set_add(sandbox_return_source_prov.legacy_origins, "sandbox_return_source_root", ctx);
    typechecker.env_record_variable_provenance(&env, "sandbox_return_source", sandbox_return_source_prov, ctx);

    mut return_type_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(return_type_idx, t_int);
    env.expected_return_type = return_type_idx;
    env.current_function_return_origins = typechecker.set_init(ctx);
    env.current_function_return_provenance = typechecker.expression_provenance_unknown(t_int, ctx);

    mut raw_return_stmt := parse_stmt_call_return_flow("return raw_return_source;", ctx);
    typechecker.check_statement(raw_return_stmt, &env, scope, ctx);

    mut raw_return_prov := env.current_function_return_provenance;
    assert_raw_call_return_flow(raw_return_prov, "raw_return_source_root", "return", "raw return boundary", ctx);

    mut sandbox_return_stmt := parse_stmt_call_return_flow("return sandbox_return_source;", ctx);
    typechecker.check_statement(sandbox_return_stmt, &env, scope, ctx);

    mut joined_return_prov := env.current_function_return_provenance;
    assert_raw_call_return_flow(joined_return_prov, "raw_return_source_root", "return", "joined return boundary", ctx);
    assert_sandbox_call_return_flow(joined_return_prov, "sandbox_return_source_root", "return", "joined return boundary", ctx);

    if len(env.errors) != 0 {
        os.LogStr("Error: raw/sandbox call-return flow fixture produced unexpected typechecker error");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: step51_raw_sandbox_provenance_call_return_flow verified raw/sandbox call and return propagation!");
}