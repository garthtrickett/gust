import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    mut t_str_callprov: ast.Type[ctx];
    unsafe {
        t_str_callprov.tag = 5; // Str
    }

    mut sig_callprov: typechecker.FunctionSignature[ctx];
    typechecker.init_function_signature_ffi_defaults(&sig_callprov);
    sig_callprov.param_names = std.VectorNew(ctx);
    sig_callprov.params = std.VectorNew(ctx);
    sig_callprov.return_type = t_str_callprov;
    sig_callprov.return_origins = typechecker.set_init(ctx);
    sig_callprov.is_unsafe = 0;

    typechecker.env_register_function(&env, "source_fn", sig_callprov, ctx);

    mut callee_origins_callprov := typechecker.set_init(ctx);
    typechecker.set_add(callee_origins_callprov, "callee_root", ctx);

    mut callee_prov_callprov := typechecker.expression_provenance_raw_derived(t_str_callprov, ctx);
    callee_prov_callprov.legacy_origins = callee_origins_callprov;
    typechecker.env_record_function_return_provenance(&env, "source_fn", callee_prov_callprov, ctx);

    mut lex_call_callprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_call_callprov, "mut out_view: str := source_fn();");
    mut parser_call_callprov: parser.Parser[ctx];
    parser.init_parser(&parser_call_callprov, &lex_call_callprov, ctx);
    mut stmt_call_callprov := parser.parse_statement(&parser_call_callprov, ctx);

    typechecker.check_statement(stmt_call_callprov, &env, scope, ctx);

    if len(env.errors) != 0 {
        os.LogStr("Error: function-call provenance fixture produced unexpected typechecker errors");
        os.Exit(1);
    }

    mut lookup_out_callprov := env.variable_provenance.Get("out_view");
    if lookup_out_callprov.Ok {
        mut out_prov_callprov := lookup_out_callprov.Val;
        if typechecker.set_contains(out_prov_callprov.legacy_origins, "callee_root", ctx) != 1 {
            os.LogStr("Error: function-call provenance did not preserve callee legacy origin");
            os.Exit(1);
        }
        if out_prov_callprov.address_origin.is_raw_derived != 1 {
            os.LogStr("Error: function-call provenance did not preserve raw-derived address origin");
            os.Exit(1);
        }
    } else {
        os.LogStr("Error: function-call provenance did not record out_view provenance");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert function-call return provenance metadata verified!");
}