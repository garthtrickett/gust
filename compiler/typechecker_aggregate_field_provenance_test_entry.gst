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

    mut t_str_fieldprov := typechecker.make_type_str();

    mut holder_layout_fieldprov: typechecker.StructLayout[ctx];
    unsafe {
        holder_layout_fieldprov.brand = empty[Index[str, ctx]];
        holder_layout_fieldprov.fields = std.HashMapNew(ctx);
    }
    holder_layout_fieldprov.fields.Insert("view", t_str_fieldprov);
    typechecker.env_register_struct(&env, "HolderFieldProv", holder_layout_fieldprov, ctx);

    mut t_holder_fieldprov := typechecker.make_type_struct("HolderFieldProv", "", ctx);
    typechecker.scope_insert(scope, "holder", t_holder_fieldprov, ctx);
    env.variable_types.Insert("holder", t_holder_fieldprov);

    typechecker.scope_insert(scope, "source_view", t_str_fieldprov, ctx);
    env.variable_types.Insert("source_view", t_str_fieldprov);

    mut source_origins_fieldprov := typechecker.set_init(ctx);
    typechecker.set_add(source_origins_fieldprov, "field_root", ctx);
    env.variable_origins.Insert("source_view", source_origins_fieldprov);

    mut source_prov_fieldprov := typechecker.expression_provenance_raw_derived(t_str_fieldprov, ctx);
    source_prov_fieldprov.legacy_origins = source_origins_fieldprov;
    typechecker.env_record_variable_provenance(&env, "source_view", source_prov_fieldprov, ctx);

    mut lex_assign_fieldprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_assign_fieldprov, "holder.view = source_view;");
    mut parser_assign_fieldprov: parser.Parser[ctx];
    parser.init_parser(&parser_assign_fieldprov, &lex_assign_fieldprov, ctx);
    mut stmt_assign_fieldprov := parser.parse_statement(&parser_assign_fieldprov, ctx);

    typechecker.check_statement(stmt_assign_fieldprov, &env, scope, ctx);

    mut lex_read_fieldprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_read_fieldprov, "mut alias_view: str := holder.view;");
    mut parser_read_fieldprov: parser.Parser[ctx];
    parser.init_parser(&parser_read_fieldprov, &lex_read_fieldprov, ctx);
    mut stmt_read_fieldprov := parser.parse_statement(&parser_read_fieldprov, ctx);

    typechecker.check_statement(stmt_read_fieldprov, &env, scope, ctx);

    if len(env.errors) != 0 {
        os.LogStr("Error: aggregate-field provenance fixture produced unexpected typechecker errors");
        os.Exit(1);
    }

    mut field_lookup_fieldprov := env.field_provenance.Get("holder.view");
    if field_lookup_fieldprov.Ok {
        mut stored_field_prov := field_lookup_fieldprov.Val;
        if typechecker.set_contains(stored_field_prov.legacy_origins, "field_root", ctx) != 1 {
            os.LogStr("Error: aggregate-field provenance did not preserve stored legacy origin");
            os.Exit(1);
        }
        if stored_field_prov.address_origin.is_raw_derived != 1 {
            os.LogStr("Error: aggregate-field provenance did not preserve stored raw-derived address origin");
            os.Exit(1);
        }
    } else {
        os.LogStr("Error: aggregate-field provenance did not record holder.view provenance");
        os.Exit(1);
    }

    mut alias_lookup_fieldprov := env.variable_provenance.Get("alias_view");
    if alias_lookup_fieldprov.Ok {
        mut alias_prov_fieldprov := alias_lookup_fieldprov.Val;
        if typechecker.set_contains(alias_prov_fieldprov.legacy_origins, "field_root", ctx) != 1 {
            os.LogStr("Error: aggregate-field readback did not preserve alias legacy origin");
            os.Exit(1);
        }
        if alias_prov_fieldprov.address_origin.is_raw_derived != 1 {
            os.LogStr("Error: aggregate-field readback did not preserve raw-derived address origin");
            os.Exit(1);
        }
    } else {
        os.LogStr("Error: aggregate-field readback did not record alias_view provenance");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: inert aggregate-field provenance metadata verified!");
}