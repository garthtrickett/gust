import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func parse_cast_probe(src: str, ctx: &Arena) Index[ast.Expression[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_expression(&p, 1, ctx);
}

func parse_cast_statement(src: str, ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_statement(&p, ctx);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    env.in_unsafe_block = 1;
    mut t_int := typechecker.make_type_int();

    mut scalar_to_raw := parse_cast_probe("0 as *int", ctx);
    mut raw_prov := typechecker.check_expression_with_provenance(scalar_to_raw, &env, scope, ctx);
    if raw_prov.resolved_type.tag != 9 ||
       typechecker.step51g_expression_provenance_is_raw_derived(raw_prov) != 1 ||
       typechecker.step51g_expression_provenance_allows_safe_brand(raw_prov, ctx) != 0 ||
       typechecker.set_contains(raw_prov.legacy_origins, "as_cast", ctx) != 1 {
        os.LogStr("Error: scalar-to-raw cast gained safe provenance");
        os.Exit(1);
    }

    typechecker.scope_insert(scope, "sandbox_source", t_int, ctx);
    env.variable_types.Insert("sandbox_source", t_int);
    mut sandbox_source := typechecker.expression_provenance_sandbox_derived(t_int, ctx);
    typechecker.env_record_variable_provenance(&env, "sandbox_source", sandbox_source, ctx);
    mut sandbox_to_raw := parse_cast_probe("sandbox_source as *int", ctx);
    mut sandbox_prov := typechecker.check_expression_with_provenance(sandbox_to_raw, &env, scope, ctx);
    if typechecker.step51g_expression_provenance_is_sandbox_derived(sandbox_prov) != 1 ||
       typechecker.step51g_expression_provenance_allows_safe_brand(sandbox_prov, ctx) != 0 {
        os.LogStr("Error: sandbox-to-raw cast lost sandbox provenance");
        os.Exit(1);
    }

    mut null_expr := parse_cast_probe("null", ctx);
    mut null_prov := typechecker.check_expression_with_provenance(null_expr, &env, scope, ctx);
    if typechecker.step51g_expression_provenance_allows_safe_brand(null_prov, ctx) != 1 ||
       typechecker.set_contains(null_prov.legacy_origins, "null", ctx) != 1 {
        os.LogStr("Error: bare null Index sentinel lost safe provenance");
        os.Exit(1);
    }

    mut scalar_cast := parse_cast_probe("0 as int", ctx);
    mut scalar_prov := typechecker.check_expression_with_provenance(scalar_cast, &env, scope, ctx);
    if typechecker.step51g_expression_provenance_allows_safe_brand(scalar_prov, ctx) != 1 {
        os.LogStr("Error: ordinary scalar cast lost safe provenance");
        os.Exit(1);
    }

    mut unsafe_gate_env := typechecker.env_new(ctx);
    mut unsafe_gate_scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut outside_unsafe := parse_cast_probe("0 as *int", ctx);
    typechecker.check_expression(outside_unsafe, &unsafe_gate_env, unsafe_gate_scope, ctx);
    if len(unsafe_gate_env.errors) == 0 ||
       std.str_find(unsafe_gate_env.errors[0].message, "Raw pointer casts are strictly prohibited outside 'unsafe' blocks") == 0 - 1 {
        os.LogStr("Error: raw-pointer cast lost explicit unsafe gate");
        os.Exit(1);
    }

    mut negative_env := typechecker.env_new(ctx);
    mut negative_scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    negative_env.in_unsafe_block = 1;
    mut t_raw := typechecker.make_type_pointer(t_int, ctx);
    typechecker.scope_insert(negative_scope, "raw_pointer", t_raw, ctx);
    negative_env.variable_types.Insert("raw_pointer", t_raw);
    typechecker.env_record_variable_provenance(&negative_env, "raw_pointer", raw_prov, ctx);
    mut forged_stmt := parse_cast_statement("mut forged: Index[int, ctx] := raw_pointer as Index[int, ctx];", ctx);
    typechecker.check_statement(forged_stmt, &negative_env, negative_scope, ctx);
    if len(negative_env.errors) == 0 ||
       std.str_find(negative_env.errors[0].message, "Non-laundering violation") == 0 - 1 {
        os.LogStr("Error: raw pointer cast into safe Index missed non-laundering rejection");
        if len(negative_env.errors) > 0 { os.LogStr(negative_env.errors[0].message); }
        os.Exit(1);
    }

    if len(env.errors) != 0 {
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
    os.LogStr("SUCCESS: raw-pointer cast provenance, safe-brand rejection, and bare-null sentinel verified");
}
