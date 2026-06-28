import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env_sel_ctorprov := typechecker.env_new(ctx);
    mut scope_sel_ctorprov := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    mut t_arena_sel_ctorprov := typechecker.make_type_arena();
    typechecker.scope_insert(scope_sel_ctorprov, "ctx", t_arena_sel_ctorprov, ctx);
    env_sel_ctorprov.variable_types.Insert("ctx", t_arena_sel_ctorprov);

    mut t_idx_sel_ctorprov := typechecker.make_type_index("SafeSelectorConstructorNode", "ctx", ctx);

    mut holder_layout_sel_ctorprov: typechecker.StructLayout[ctx];
    unsafe {
        holder_layout_sel_ctorprov.brand = empty[Index[str, ctx]];
        holder_layout_sel_ctorprov.fields = std.HashMapNew(ctx);
    }
    holder_layout_sel_ctorprov.fields.Insert("survivor", t_idx_sel_ctorprov);
    typechecker.env_register_struct(&env_sel_ctorprov, "SafeSelectorConstructorHolder", holder_layout_sel_ctorprov, ctx);

    mut t_holder_sel_ctorprov := typechecker.make_type_struct("SafeSelectorConstructorHolder", "", ctx);
    typechecker.scope_insert(scope_sel_ctorprov, "holder_sel_ctorprov", t_holder_sel_ctorprov, ctx);
    env_sel_ctorprov.variable_types.Insert("holder_sel_ctorprov", t_holder_sel_ctorprov);

    mut lex_assign_sel_ctorprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_assign_sel_ctorprov, "holder_sel_ctorprov.survivor = os.ArenaAlloc(ctx);");
    mut parser_assign_sel_ctorprov: parser.Parser[ctx];
    parser.init_parser(&parser_assign_sel_ctorprov, &lex_assign_sel_ctorprov, ctx);
    mut stmt_assign_sel_ctorprov := parser.parse_statement(&parser_assign_sel_ctorprov, ctx);

    typechecker.check_statement(stmt_assign_sel_ctorprov, &env_sel_ctorprov, scope_sel_ctorprov, ctx);

    if len(env_sel_ctorprov.errors) != 0 {
        os.LogStr("Error: selector safe constructor assignment produced unexpected typechecker error");
        os.LogStr(env_sel_ctorprov.errors[0].message);
        os.Exit(1);
    }

    mut lex_safe_ref_sel_ctorprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_safe_ref_sel_ctorprov, "ctx.get_ref(holder_sel_ctorprov.survivor)");
    mut parser_safe_ref_sel_ctorprov: parser.Parser[ctx];
    parser.init_parser(&parser_safe_ref_sel_ctorprov, &lex_safe_ref_sel_ctorprov, ctx);
    mut expr_safe_ref_sel_ctorprov := parser.parse_expression(&parser_safe_ref_sel_ctorprov, 1, ctx);

    mut safe_ref_prov_sel_ctorprov := typechecker.check_expression_with_provenance(expr_safe_ref_sel_ctorprov, &env_sel_ctorprov, scope_sel_ctorprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(safe_ref_prov_sel_ctorprov) != 1 {
        os.LogStr("Error: ctx.get_ref(selector field with safe constructor provenance) did not preserve safe-arena provenance");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_sel_ctorprov, "holder_raw_sel_ctorprov", t_holder_sel_ctorprov, ctx);
    env_sel_ctorprov.variable_types.Insert("holder_raw_sel_ctorprov", t_holder_sel_ctorprov);

    mut raw_origins_sel_ctorprov := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_sel_ctorprov, "raw_selector_ctor_root", ctx);

    mut raw_field_prov_sel_ctorprov := typechecker.expression_provenance_raw_derived(t_idx_sel_ctorprov, ctx);
    raw_field_prov_sel_ctorprov.legacy_origins = raw_origins_sel_ctorprov;
    typechecker.env_record_field_provenance(&env_sel_ctorprov, "holder_raw_sel_ctorprov.survivor", raw_field_prov_sel_ctorprov, ctx);

    mut lex_raw_ref_sel_ctorprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_ref_sel_ctorprov, "ctx.get_ref(holder_raw_sel_ctorprov.survivor)");
    mut parser_raw_ref_sel_ctorprov: parser.Parser[ctx];
    parser.init_parser(&parser_raw_ref_sel_ctorprov, &lex_raw_ref_sel_ctorprov, ctx);
    mut expr_raw_ref_sel_ctorprov := parser.parse_expression(&parser_raw_ref_sel_ctorprov, 1, ctx);

    mut raw_ref_prov_sel_ctorprov := typechecker.check_expression_with_provenance(expr_raw_ref_sel_ctorprov, &env_sel_ctorprov, scope_sel_ctorprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(raw_ref_prov_sel_ctorprov) == 1 {
        os.LogStr("Error: ctx.get_ref(selector field with raw-derived provenance) incorrectly allowed safe branding");
        os.Exit(1);
    }
    if typechecker.expression_provenance_is_raw_or_sandbox_derived(raw_ref_prov_sel_ctorprov) != 1 {
        os.LogStr("Error: ctx.get_ref(selector field with raw-derived provenance) did not preserve unsafe-derived metadata");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: selector safe constructor provenance metadata verified!");
}