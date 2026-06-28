import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_arena_refaliasprov := typechecker.make_type_arena();
    mut t_int_refaliasprov := typechecker.make_type_int();
    mut t_node_idx_refaliasprov := typechecker.make_type_index("ReferenceSelectorAliasNode", "ctx", ctx);
    mut t_holder_struct_refaliasprov := typechecker.make_type_struct("ReferenceSelectorAliasHolder", "ctx", ctx);
    mut t_holder_idx_refaliasprov := typechecker.make_type_index("ReferenceSelectorAliasHolder", "ctx", ctx);
    mut t_ptr_holder_refaliasprov := typechecker.make_type_pointer(t_holder_struct_refaliasprov, ctx);

    mut holder_layout_refaliasprov: typechecker.StructLayout[ctx];
    unsafe {
        holder_layout_refaliasprov.brand = empty[Index[str, ctx]];
        holder_layout_refaliasprov.fields = std.HashMapNew(ctx);
    }
    holder_layout_refaliasprov.fields.Insert("survivor", t_node_idx_refaliasprov);

    mut vector_layout_refaliasprov: typechecker.StructLayout[ctx];
    unsafe {
        vector_layout_refaliasprov.brand = empty[Index[str, ctx]];
        vector_layout_refaliasprov.fields = std.HashMapNew(ctx);
    }
    vector_layout_refaliasprov.fields.Insert("data", t_ptr_holder_refaliasprov);

    mut t_vector_refaliasprov := typechecker.make_type_struct("Vector_ReferenceSelectorAliasHolder", "", ctx);

    mut env_refaliasprov := typechecker.env_new(ctx);
    mut scope_refaliasprov := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_refaliasprov, "ReferenceSelectorAliasHolder", holder_layout_refaliasprov, ctx);
    typechecker.env_register_struct(&env_refaliasprov, "Vector_ReferenceSelectorAliasHolder", vector_layout_refaliasprov, ctx);

    typechecker.scope_insert(scope_refaliasprov, "ctx", t_arena_refaliasprov, ctx);
    env_refaliasprov.variable_types.Insert("ctx", t_arena_refaliasprov);

    typechecker.scope_insert(scope_refaliasprov, "holder_idx_refaliasprov", t_holder_idx_refaliasprov, ctx);
    env_refaliasprov.variable_types.Insert("holder_idx_refaliasprov", t_holder_idx_refaliasprov);

    typechecker.scope_insert(scope_refaliasprov, "safe_idx_refaliasprov", t_node_idx_refaliasprov, ctx);
    env_refaliasprov.variable_types.Insert("safe_idx_refaliasprov", t_node_idx_refaliasprov);

    mut safe_origins_refaliasprov := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_refaliasprov, "safe_reference_selector_alias_root", ctx);
    env_refaliasprov.variable_origins.Insert("safe_idx_refaliasprov", safe_origins_refaliasprov);

    mut safe_prov_refaliasprov := typechecker.expression_provenance_safe_arena(t_node_idx_refaliasprov, ctx);
    safe_prov_refaliasprov.legacy_origins = safe_origins_refaliasprov;
    typechecker.env_record_variable_provenance(&env_refaliasprov, "safe_idx_refaliasprov", safe_prov_refaliasprov, ctx);

    mut lex_arena_refaliasprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_arena_refaliasprov, "ctx.get_ref(holder_idx_refaliasprov).survivor = safe_idx_refaliasprov;");
    mut parser_arena_refaliasprov: parser.Parser[ctx];
    parser.init_parser(&parser_arena_refaliasprov, &lex_arena_refaliasprov, ctx);
    mut stmt_arena_refaliasprov := parser.parse_statement(&parser_arena_refaliasprov, ctx);

    typechecker.check_statement(stmt_arena_refaliasprov, &env_refaliasprov, scope_refaliasprov, ctx);

    if len(env_refaliasprov.errors) != 0 {
        os.LogStr("Error: Arena get_ref selector alias fixture produced unexpected typechecker error");
        os.LogStr(env_refaliasprov.errors[0].message);
        os.Exit(1);
    }

    mut lex_arena_read_refaliasprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_arena_read_refaliasprov, "ctx[holder_idx_refaliasprov].survivor");
    mut parser_arena_read_refaliasprov: parser.Parser[ctx];
    parser.init_parser(&parser_arena_read_refaliasprov, &lex_arena_read_refaliasprov, ctx);
    mut expr_arena_read_refaliasprov := parser.parse_expression(&parser_arena_read_refaliasprov, 1, ctx);

    mut arena_read_prov_refaliasprov := typechecker.check_expression_with_provenance(expr_arena_read_refaliasprov, &env_refaliasprov, scope_refaliasprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(arena_read_prov_refaliasprov) != 1 {
        os.LogStr("Error: ctx.get_ref(...).field write did not alias provenance to ctx[index].field readback");
        os.Exit(1);
    }
    if typechecker.set_contains(arena_read_prov_refaliasprov.legacy_origins, "safe_reference_selector_alias_root", ctx) != 1 {
        os.LogStr("Error: ctx.get_ref(...).field alias did not preserve legacy origin");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_refaliasprov, "values_refaliasprov", t_vector_refaliasprov, ctx);
    env_refaliasprov.variable_types.Insert("values_refaliasprov", t_vector_refaliasprov);

    typechecker.scope_insert(scope_refaliasprov, "i_refaliasprov", t_int_refaliasprov, ctx);
    env_refaliasprov.variable_types.Insert("i_refaliasprov", t_int_refaliasprov);

    mut lex_vector_refaliasprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_vector_refaliasprov, "values_refaliasprov.GetRef(i_refaliasprov).survivor = safe_idx_refaliasprov;");
    mut parser_vector_refaliasprov: parser.Parser[ctx];
    parser.init_parser(&parser_vector_refaliasprov, &lex_vector_refaliasprov, ctx);
    mut stmt_vector_refaliasprov := parser.parse_statement(&parser_vector_refaliasprov, ctx);

    typechecker.check_statement(stmt_vector_refaliasprov, &env_refaliasprov, scope_refaliasprov, ctx);

    if len(env_refaliasprov.errors) != 0 {
        os.LogStr("Error: Vector.GetRef selector alias fixture produced unexpected typechecker error");
        os.LogStr(env_refaliasprov.errors[0].message);
        os.Exit(1);
    }

    mut lex_vector_read_refaliasprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_vector_read_refaliasprov, "values_refaliasprov[i_refaliasprov].survivor");
    mut parser_vector_read_refaliasprov: parser.Parser[ctx];
    parser.init_parser(&parser_vector_read_refaliasprov, &lex_vector_read_refaliasprov, ctx);
    mut expr_vector_read_refaliasprov := parser.parse_expression(&parser_vector_read_refaliasprov, 1, ctx);

    mut vector_read_prov_refaliasprov := typechecker.check_expression_with_provenance(expr_vector_read_refaliasprov, &env_refaliasprov, scope_refaliasprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(vector_read_prov_refaliasprov) != 1 {
        os.LogStr("Error: Vector.GetRef(...).field write did not alias provenance to values[index].field readback");
        os.Exit(1);
    }
    if typechecker.set_contains(vector_read_prov_refaliasprov.legacy_origins, "safe_reference_selector_alias_root", ctx) != 1 {
        os.LogStr("Error: Vector.GetRef(...).field alias did not preserve legacy origin");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: reference selector alias provenance metadata verified!");
}