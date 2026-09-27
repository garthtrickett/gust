import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func parse_return(src: str, ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_statement(&p, ctx);
}

func check_return_case(kind: int, ctx: &Arena) {
    mut ref_type := typechecker.make_type_reference(typechecker.make_type_int(), "", ctx);
    if typechecker.step51g_non_laundering_type_is_safe_brand_target(ref_type, ctx) != 0 {
        os.LogStr("Error: unbranded Reference was reclassified as a safe-branded target");
        os.Exit(1);
    }
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.scope_insert(scope, "ref_value", ref_type, ctx);
    env.variable_types.Insert("ref_value", ref_type);
    mut origins := typechecker.set_init(ctx);
    typechecker.set_add(origins, "source", ctx);
    env.variable_origins.Insert("ref_value", origins);
    mut prov := typechecker.expression_provenance_unknown(ref_type, ctx);
    if kind == 1 { prov = typechecker.expression_provenance_raw_derived(ref_type, ctx); }
    if kind == 2 { prov = typechecker.expression_provenance_sandbox_derived(ref_type, ctx); }
    if kind == 3 { prov = typechecker.expression_provenance_safe_arena(ref_type, ctx); }
    prov.legacy_origins = origins;
    typechecker.env_record_variable_provenance(&env, "ref_value", prov, ctx);
    mut return_type: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(return_type, ref_type);
    env.expected_return_type = return_type;
    env.current_function_return_origins = typechecker.set_init(ctx);
    env.current_function_return_provenance = typechecker.expression_provenance_unknown(ref_type, ctx);

    if kind == 1 {
        env.in_unsafe_block = 1;
        mut local_binding := parse_return("mut local_ref: &int := ref_value;", ctx);
        typechecker.check_statement(local_binding, &env, scope, ctx);
        if len(env.errors) != 0 {
            os.LogStr("Error: unsafe local unbranded Reference binding changed");
            os.LogStr(env.errors[0].message);
            os.Exit(1);
        }
    }
    mut returned := parse_return("return ref_value;", ctx);
    typechecker.check_statement(returned, &env, scope, ctx);
    if kind == 1 || kind == 2 {
        if len(env.errors) != 1 ||
           std.str_find(env.errors[0].message, "[UnsafeReferenceEscape]") == 0 - 1 {
            os.LogStr("Error: derived unbranded Reference return missed exact diagnostic");
            if len(env.errors) > 0 { os.LogStr(env.errors[0].message); }
            os.Exit(1);
        }
    } else {
        if len(env.errors) != 0 {
            os.LogStr("Error: safe or unknown Reference return changed");
            os.LogStr(env.errors[0].message);
            os.Exit(1);
        }
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);
    check_return_case(0, ctx);
    check_return_case(1, ctx);
    check_return_case(2, ctx);
    check_return_case(3, ctx);
    os.LogStr("SUCCESS: unbranded Reference return escape boundary verified");
}
