import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func parse_expr_field_flow(src: str, ctx: &Arena) Index[ast.Expression[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_expression(&p, 1, ctx);
}

func parse_stmt_field_flow(src: str, ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_statement(&p, ctx);
}

func assert_raw_field_flow(prov: typechecker.ExpressionProvenance[ctx], origin: str, label: str, message: str, ctx: &Arena) {
    if typechecker.step51g_expression_provenance_is_raw_derived(prov) != 1 {
        os.LogStr(std.Concat("Error: raw field/aggregate flow did not preserve raw-derived provenance for ", message));
        os.Exit(1);
    }
    if typechecker.set_contains(prov.legacy_origins, origin, ctx) != 1 {
        os.LogStr(std.Concat("Error: raw field/aggregate flow did not preserve legacy origin for ", message));
        os.Exit(1);
    }
    if std.str_eq(label, "") == 0 {
        if typechecker.set_contains(prov.legacy_origins, label, ctx) != 1 {
            os.LogStr(std.Concat("Error: raw field/aggregate flow did not stamp projection label for ", message));
            os.Exit(1);
        }
    }
}

func assert_sandbox_field_flow(prov: typechecker.ExpressionProvenance[ctx], origin: str, label: str, message: str, ctx: &Arena) {
    if typechecker.step51g_expression_provenance_is_sandbox_derived(prov) != 1 {
        os.LogStr(std.Concat("Error: sandbox field/aggregate flow did not preserve sandbox-derived provenance for ", message));
        os.Exit(1);
    }
    if typechecker.set_contains(prov.legacy_origins, origin, ctx) != 1 {
        os.LogStr(std.Concat("Error: sandbox field/aggregate flow did not preserve legacy origin for ", message));
        os.Exit(1);
    }
    if std.str_eq(label, "") == 0 {
        if typechecker.set_contains(prov.legacy_origins, label, ctx) != 1 {
            os.LogStr(std.Concat("Error: sandbox field/aggregate flow did not stamp projection label for ", message));
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
    mut holder_layout: typechecker.StructLayout[ctx];
    unsafe {
        holder_layout.brand = empty[Index[str, ctx]];
        holder_layout.fields = std.HashMapNew(ctx);
    }
    holder_layout.fields.Insert("payload", t_int);
    typechecker.env_register_struct(&env, "RawSandboxFieldFlowHolder", holder_layout, ctx);
    mut t_holder := typechecker.make_type_struct("RawSandboxFieldFlowHolder", "", ctx);

    typechecker.scope_insert(scope, "holder_raw_field_flow", t_holder, ctx);
    env.variable_types.Insert("holder_raw_field_flow", t_holder);
    typechecker.scope_insert(scope, "raw_field_source", t_int, ctx);
    env.variable_types.Insert("raw_field_source", t_int);
    mut raw_source_prov := typechecker.expression_provenance_raw_derived(t_int, ctx);
    typechecker.set_add(raw_source_prov.legacy_origins, "raw_field_flow_root", ctx);
    typechecker.env_record_variable_provenance(&env, "raw_field_source", raw_source_prov, ctx);

    mut raw_assign_stmt := parse_stmt_field_flow("holder_raw_field_flow.payload = raw_field_source;", ctx);
    typechecker.check_statement(raw_assign_stmt, &env, scope, ctx);

    mut raw_field_expr := parse_expr_field_flow("holder_raw_field_flow.payload", ctx);
    mut raw_field_prov := typechecker.check_expression_with_provenance(raw_field_expr, &env, scope, ctx);
    assert_raw_field_flow(raw_field_prov, "raw_field_flow_root", "field:payload", "field assignment/readback", ctx);

    env.in_unsafe_block = 1;
    mut raw_field_address_expr := parse_expr_field_flow("&holder_raw_field_flow.payload", ctx);
    mut raw_field_address_prov := typechecker.check_expression_with_provenance(raw_field_address_expr, &env, scope, ctx);
    env.in_unsafe_block = 0;
    assert_raw_field_flow(raw_field_address_prov, "raw_field_flow_root", "address_of", "address-of field", ctx);
    if typechecker.set_contains(raw_field_address_prov.legacy_origins, "field:payload", ctx) != 1 {
        os.LogStr("Error: address-of field did not retain field projection label");
        os.Exit(1);
    }

    typechecker.scope_insert(scope, "holder_sandbox_field_flow", t_holder, ctx);
    env.variable_types.Insert("holder_sandbox_field_flow", t_holder);
    typechecker.scope_insert(scope, "sandbox_field_source", t_int, ctx);
    env.variable_types.Insert("sandbox_field_source", t_int);
    mut sandbox_source_prov := typechecker.expression_provenance_sandbox_derived(t_int, ctx);
    typechecker.set_add(sandbox_source_prov.legacy_origins, "sandbox_field_flow_root", ctx);
    typechecker.env_record_variable_provenance(&env, "sandbox_field_source", sandbox_source_prov, ctx);

    mut sandbox_assign_stmt := parse_stmt_field_flow("holder_sandbox_field_flow.payload = sandbox_field_source;", ctx);
    typechecker.check_statement(sandbox_assign_stmt, &env, scope, ctx);

    mut sandbox_field_expr := parse_expr_field_flow("holder_sandbox_field_flow.payload", ctx);
    mut sandbox_field_prov := typechecker.check_expression_with_provenance(sandbox_field_expr, &env, scope, ctx);
    assert_sandbox_field_flow(sandbox_field_prov, "sandbox_field_flow_root", "field:payload", "sandbox field assignment/readback", ctx);

    typechecker.scope_insert(scope, "aggregate_raw_field_flow", t_holder, ctx);
    env.variable_types.Insert("aggregate_raw_field_flow", t_holder);
    mut raw_member_prov := typechecker.expression_provenance_raw_derived(t_int, ctx);
    typechecker.set_add(raw_member_prov.legacy_origins, "raw_aggregate_field_flow_root", ctx);
    mut aggregate_origins := typechecker.set_init(ctx);
    mut aggregate_raw_prov := typechecker.step51g_expression_provenance_aggregate_from_member_preserving_raw_sandbox(raw_member_prov, t_holder, aggregate_origins, "payload", ctx);
    typechecker.env_record_variable_provenance(&env, "aggregate_raw_field_flow", aggregate_raw_prov, ctx);

    mut aggregate_field_expr := parse_expr_field_flow("aggregate_raw_field_flow.payload", ctx);
    mut aggregate_field_prov := typechecker.check_expression_with_provenance(aggregate_field_expr, &env, scope, ctx);
    assert_raw_field_flow(aggregate_field_prov, "raw_aggregate_field_flow_root", "field:payload", "aggregate field projection", ctx);
    if typechecker.set_contains(aggregate_field_prov.legacy_origins, "aggregate:payload", ctx) != 1 {
        os.LogStr("Error: aggregate field projection did not retain aggregate construction label");
        os.Exit(1);
    }

    if len(env.errors) != 0 {
        os.LogStr("Error: raw/sandbox field aggregate flow fixture produced unexpected typechecker error");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: step51_raw_sandbox_provenance_field_aggregate_flow");
}
