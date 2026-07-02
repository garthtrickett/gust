import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func parse_expr_expression_flow(src: str, ctx: &Arena) Index[ast.Expression[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_expression(&p, 1, ctx);
}

func assert_raw_expr_flow(prov: typechecker.ExpressionProvenance[ctx], origin: str, label: str, message: str, ctx: &Arena) {
    if typechecker.step51g_expression_provenance_is_raw_derived(prov) != 1 {
        os.LogStr(std.Concat("Error: raw expression flow did not preserve raw-derived provenance for ", message));
        os.Exit(1);
    }
    if typechecker.set_contains(prov.legacy_origins, origin, ctx) != 1 {
        os.LogStr(std.Concat("Error: raw expression flow did not preserve legacy origin for ", message));
        os.Exit(1);
    }
    if std.str_eq(label, "") == 0 {
        if typechecker.set_contains(prov.legacy_origins, label, ctx) != 1 {
            os.LogStr(std.Concat("Error: raw expression flow did not stamp flow label for ", message));
            os.Exit(1);
        }
    }
}

func assert_sandbox_expr_flow(prov: typechecker.ExpressionProvenance[ctx], origin: str, label: str, message: str, ctx: &Arena) {
    if typechecker.step51g_expression_provenance_is_sandbox_derived(prov) != 1 {
        os.LogStr(std.Concat("Error: sandbox expression flow did not preserve sandbox-derived provenance for ", message));
        os.Exit(1);
    }
    if typechecker.set_contains(prov.legacy_origins, origin, ctx) != 1 {
        os.LogStr(std.Concat("Error: sandbox expression flow did not preserve legacy origin for ", message));
        os.Exit(1);
    }
    if std.str_eq(label, "") == 0 {
        if typechecker.set_contains(prov.legacy_origins, label, ctx) != 1 {
            os.LogStr(std.Concat("Error: sandbox expression flow did not stamp flow label for ", message));
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
    mut t_raw_int := typechecker.make_type_pointer(t_int, ctx);

    typechecker.scope_insert(scope, "raw_expr_flow", t_int, ctx);
    env.variable_types.Insert("raw_expr_flow", t_int);
    mut raw_source_prov := typechecker.expression_provenance_raw_derived(t_int, ctx);
    typechecker.set_add(raw_source_prov.legacy_origins, "raw_expression_flow_root", ctx);
    typechecker.env_record_variable_provenance(&env, "raw_expr_flow", raw_source_prov, ctx);

    typechecker.scope_insert(scope, "sandbox_expr_flow", t_int, ctx);
    env.variable_types.Insert("sandbox_expr_flow", t_int);
    mut sandbox_source_prov := typechecker.expression_provenance_sandbox_derived(t_int, ctx);
    typechecker.set_add(sandbox_source_prov.legacy_origins, "sandbox_expression_flow_root", ctx);
    typechecker.env_record_variable_provenance(&env, "sandbox_expr_flow", sandbox_source_prov, ctx);

    typechecker.scope_insert(scope, "safe_expr_flow", t_int, ctx);
    env.variable_types.Insert("safe_expr_flow", t_int);
    typechecker.env_record_variable_self_provenance(&env, "safe_expr_flow", t_int, ctx);

    mut move_expr := parse_expr_expression_flow("move raw_expr_flow", ctx);
    mut move_prov := typechecker.check_expression_with_provenance(move_expr, &env, scope, ctx);
    assert_raw_expr_flow(move_prov, "raw_expression_flow_root", "move", "move", ctx);

    mut binary_left_expr := parse_expr_expression_flow("raw_expr_flow + safe_expr_flow", ctx);
    mut binary_left_prov := typechecker.check_expression_with_provenance(binary_left_expr, &env, scope, ctx);
    assert_raw_expr_flow(binary_left_prov, "raw_expression_flow_root", "binary", "binary-left", ctx);

    mut binary_right_expr := parse_expr_expression_flow("safe_expr_flow + sandbox_expr_flow", ctx);
    mut binary_right_prov := typechecker.check_expression_with_provenance(binary_right_expr, &env, scope, ctx);
    assert_sandbox_expr_flow(binary_right_prov, "sandbox_expression_flow_root", "binary", "binary-right", ctx);

    typechecker.scope_insert(scope, "raw_ptr_expr_flow", t_raw_int, ctx);
    env.variable_types.Insert("raw_ptr_expr_flow", t_raw_int);
    mut raw_ptr_prov := typechecker.expression_provenance_raw_derived(t_raw_int, ctx);
    typechecker.set_add(raw_ptr_prov.legacy_origins, "raw_pointer_expression_flow_root", ctx);
    typechecker.env_record_variable_provenance(&env, "raw_ptr_expr_flow", raw_ptr_prov, ctx);

    env.in_unsafe_block = 1;
    mut deref_expr := parse_expr_expression_flow("*raw_ptr_expr_flow", ctx);
    mut deref_prov := typechecker.check_expression_with_provenance(deref_expr, &env, scope, ctx);
    env.in_unsafe_block = 0;
    assert_raw_expr_flow(deref_prov, "raw_pointer_expression_flow_root", "", "dereference", ctx);

    mut address_expr := parse_expr_expression_flow("&raw_expr_flow", ctx);
    mut address_prov := typechecker.check_expression_with_provenance(address_expr, &env, scope, ctx);
    assert_raw_expr_flow(address_prov, "raw_expression_flow_root", "address_of", "address-of", ctx);

    if len(env.errors) != 0 {
        os.LogStr("Error: raw/sandbox expression flow fixture produced unexpected typechecker error");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: step51_raw_sandbox_provenance_expression_flow");
}