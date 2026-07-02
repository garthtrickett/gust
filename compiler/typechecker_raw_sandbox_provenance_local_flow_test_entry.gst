import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func parse_stmt_local_flow(src: str, ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_statement(&p, ctx);
}

func parse_expr_local_flow(src: str, ctx: &Arena) Index[ast.Expression[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_expression(&p, 1, ctx);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut t_int := typechecker.make_type_int();

    typechecker.scope_insert(scope, "source_raw_local_flow", t_int, ctx);
    env.variable_types.Insert("source_raw_local_flow", t_int);

    mut raw_source_prov := typechecker.expression_provenance_raw_derived(t_int, ctx);
    typechecker.set_add(raw_source_prov.legacy_origins, "raw_local_flow_root", ctx);
    typechecker.env_record_variable_provenance(&env, "source_raw_local_flow", raw_source_prov, ctx);

    mut bind_stmt := parse_stmt_local_flow("mut alias_raw_local_flow := source_raw_local_flow;", ctx);
    typechecker.check_statement(bind_stmt, &env, scope, ctx);

    mut alias_lookup := env.variable_provenance.Get("alias_raw_local_flow");
    if alias_lookup.Ok {
        mut alias_prov := alias_lookup.Val;
        if typechecker.step51g_expression_provenance_is_raw_derived(alias_prov) != 1 {
            os.LogStr("Error: raw local binding did not preserve raw-derived provenance");
            os.Exit(1);
        }
        if typechecker.set_contains(alias_prov.legacy_origins, "raw_local_flow_root", ctx) != 1 {
            os.LogStr("Error: raw local binding did not preserve raw legacy origin");
            os.Exit(1);
        }
    } else {
        os.LogStr("Error: raw local binding did not record variable provenance");
        os.Exit(1);
    }

    typechecker.scope_insert(scope, "target_raw_local_flow", t_int, ctx);
    env.variable_types.Insert("target_raw_local_flow", t_int);
    typechecker.env_record_variable_self_provenance(&env, "target_raw_local_flow", t_int, ctx);

    mut assign_stmt := parse_stmt_local_flow("target_raw_local_flow = source_raw_local_flow;", ctx);
    typechecker.check_statement(assign_stmt, &env, scope, ctx);

    mut assign_lookup := env.variable_provenance.Get("target_raw_local_flow");
    if assign_lookup.Ok {
        mut assign_prov := assign_lookup.Val;
        if typechecker.step51g_expression_provenance_is_raw_derived(assign_prov) != 1 {
            os.LogStr("Error: raw assignment did not preserve raw-derived provenance");
            os.Exit(1);
        }
        if typechecker.set_contains(assign_prov.legacy_origins, "raw_local_flow_root", ctx) != 1 {
            os.LogStr("Error: raw assignment did not preserve raw legacy origin");
            os.Exit(1);
        }
    } else {
        os.LogStr("Error: raw assignment did not record target variable provenance");
        os.Exit(1);
    }

    mut cast_expr := parse_expr_local_flow("source_raw_local_flow as int", ctx);
    mut cast_prov := typechecker.check_expression_with_provenance(cast_expr, &env, scope, ctx);
    if typechecker.step51g_expression_provenance_is_raw_derived(cast_prov) != 1 {
        os.LogStr("Error: raw cast did not preserve raw-derived provenance");
        os.Exit(1);
    }
    if typechecker.set_contains(cast_prov.legacy_origins, "raw_local_flow_root", ctx) != 1 {
        os.LogStr("Error: raw cast did not preserve raw legacy origin");
        os.Exit(1);
    }
    if typechecker.set_contains(cast_prov.legacy_origins, "as_cast", ctx) != 1 {
        os.LogStr("Error: raw cast did not stamp as_cast flow origin");
        os.Exit(1);
    }

    typechecker.scope_insert(scope, "source_sandbox_local_flow", t_int, ctx);
    env.variable_types.Insert("source_sandbox_local_flow", t_int);
    mut sandbox_source_prov := typechecker.expression_provenance_sandbox_derived(t_int, ctx);
    typechecker.set_add(sandbox_source_prov.legacy_origins, "sandbox_local_flow_root", ctx);
    typechecker.env_record_variable_provenance(&env, "source_sandbox_local_flow", sandbox_source_prov, ctx);

    mut sandbox_bind_stmt := parse_stmt_local_flow("mut alias_sandbox_local_flow := source_sandbox_local_flow;", ctx);
    typechecker.check_statement(sandbox_bind_stmt, &env, scope, ctx);

    mut sandbox_alias_lookup := env.variable_provenance.Get("alias_sandbox_local_flow");
    if sandbox_alias_lookup.Ok {
        mut sandbox_alias_prov := sandbox_alias_lookup.Val;
        if typechecker.step51g_expression_provenance_is_sandbox_derived(sandbox_alias_prov) != 1 {
            os.LogStr("Error: sandbox local binding did not preserve sandbox-derived provenance");
            os.Exit(1);
        }
        if typechecker.set_contains(sandbox_alias_prov.legacy_origins, "sandbox_local_flow_root", ctx) != 1 {
            os.LogStr("Error: sandbox local binding did not preserve sandbox legacy origin");
            os.Exit(1);
        }
    } else {
        os.LogStr("Error: sandbox local binding did not record variable provenance");
        os.Exit(1);
    }

    if len(env.errors) != 0 {
        os.LogStr("Error: raw/sandbox local flow fixture produced unexpected typechecker error");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: raw/sandbox local binding, assignment, and cast provenance propagation verified!");
}
