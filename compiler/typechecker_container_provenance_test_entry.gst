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

    mut t_str_contprov := typechecker.make_type_str();
    mut t_int_contprov := typechecker.make_type_int();
    mut t_ptr_str_contprov := typechecker.make_type_pointer(t_str_contprov, ctx);

    mut vector_layout_contprov: typechecker.StructLayout[ctx];
    unsafe {
        vector_layout_contprov.brand = empty[Index[str, ctx]];
        vector_layout_contprov.fields = std.HashMapNew(ctx);
    }
    vector_layout_contprov.fields.Insert("data", t_ptr_str_contprov);
    typechecker.env_register_struct(&env, "MockVectorContProv", vector_layout_contprov, ctx);
    typechecker.env_record_struct_container_kind(&env, "MockVectorContProv", typechecker.typechecker_container_kind_vector(), ctx);

    mut t_vector_contprov := typechecker.make_type_struct("MockVectorContProv", "", ctx);
    typechecker.scope_insert(scope, "values", t_vector_contprov, ctx);
    env.variable_types.Insert("values", t_vector_contprov);

    typechecker.scope_insert(scope, "i", t_int_contprov, ctx);
    env.variable_types.Insert("i", t_int_contprov);

    typechecker.scope_insert(scope, "source_view", t_str_contprov, ctx);
    env.variable_types.Insert("source_view", t_str_contprov);

    mut source_origins_contprov := typechecker.set_init(ctx);
    typechecker.set_add(source_origins_contprov, "container_root", ctx);
    env.variable_origins.Insert("source_view", source_origins_contprov);

    mut source_prov_contprov := typechecker.expression_provenance_raw_derived(t_str_contprov, ctx);
    source_prov_contprov.legacy_origins = source_origins_contprov;
    typechecker.env_record_variable_provenance(&env, "source_view", source_prov_contprov, ctx);

    mut lex_assign_contprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_assign_contprov, "unsafe { values[i] = source_view; }");
    mut parser_assign_contprov: parser.Parser[ctx];
    parser.init_parser(&parser_assign_contprov, &lex_assign_contprov, ctx);
    mut stmt_assign_contprov := parser.parse_statement(&parser_assign_contprov, ctx);

    typechecker.check_statement(stmt_assign_contprov, &env, scope, ctx);

    mut lex_read_contprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_read_contprov, "mut alias_view: str := values[i];");
    mut parser_read_contprov: parser.Parser[ctx];
    parser.init_parser(&parser_read_contprov, &lex_read_contprov, ctx);
    mut stmt_read_contprov := parser.parse_statement(&parser_read_contprov, ctx);

    typechecker.check_statement(stmt_read_contprov, &env, scope, ctx);

    if len(env.errors) != 0 {
        os.LogStr("Error: container provenance fixture produced unexpected typechecker errors");
        os.Exit(1);
    }

    mut container_lookup_contprov := env.container_provenance.Get("values[i]");
    if container_lookup_contprov.Ok {
        mut stored_container_prov := container_lookup_contprov.Val;
        if typechecker.set_contains(stored_container_prov.legacy_origins, "container_root", ctx) != 1 {
            os.LogStr("Error: container provenance did not preserve stored legacy origin");
            os.Exit(1);
        }
        if stored_container_prov.address_origin.is_raw_derived != 1 {
            os.LogStr("Error: container provenance did not preserve stored raw-derived address origin");
            os.Exit(1);
        }
    } else {
        os.LogStr("Error: container provenance did not record values[i] provenance");
        os.Exit(1);
    }

    mut alias_lookup_contprov := env.variable_provenance.Get("alias_view");
    if alias_lookup_contprov.Ok {
        mut alias_prov_contprov := alias_lookup_contprov.Val;
        if typechecker.set_contains(alias_prov_contprov.legacy_origins, "container_root", ctx) != 1 {
            os.LogStr("Error: container readback did not preserve alias legacy origin");
            os.Exit(1);
        }
        if alias_prov_contprov.address_origin.is_raw_derived != 1 {
            os.LogStr("Error: container readback did not preserve raw-derived address origin");
            os.Exit(1);
        }
    } else {
        os.LogStr("Error: container readback did not record alias_view provenance");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert container provenance metadata verified!");
}
