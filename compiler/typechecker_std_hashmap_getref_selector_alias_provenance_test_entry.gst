import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_int_stdhashaliasprov := typechecker.make_type_int();
    mut t_node_idx_stdhashaliasprov := typechecker.make_type_index("StdHashMapGetRefAliasNode", "ctx", ctx);
    mut t_holder_struct_stdhashaliasprov := typechecker.make_type_struct("StdHashMapGetRefAliasHolder", "ctx", ctx);
    mut t_ptr_int_stdhashaliasprov := typechecker.make_type_pointer(t_int_stdhashaliasprov, ctx);
    mut t_ptr_holder_stdhashaliasprov := typechecker.make_type_pointer(t_holder_struct_stdhashaliasprov, ctx);

    mut holder_layout_stdhashaliasprov: typechecker.StructLayout[ctx];
    unsafe {
        holder_layout_stdhashaliasprov.brand = empty[Index[str, ctx]];
        holder_layout_stdhashaliasprov.fields = std.HashMapNew(ctx);
    }
    holder_layout_stdhashaliasprov.fields.Insert("survivor", t_node_idx_stdhashaliasprov);

    mut map_layout_stdhashaliasprov: typechecker.StructLayout[ctx];
    unsafe {
        map_layout_stdhashaliasprov.brand = empty[Index[str, ctx]];
        map_layout_stdhashaliasprov.fields = std.HashMapNew(ctx);
    }
    map_layout_stdhashaliasprov.fields.Insert("keys", t_ptr_int_stdhashaliasprov);
    map_layout_stdhashaliasprov.fields.Insert("values", t_ptr_holder_stdhashaliasprov);

    mut t_map_stdhashaliasprov := typechecker.make_type_struct("HashMap_Int_StdHashMapGetRefAliasHolder", "", ctx);

    mut env_stdhashaliasprov := typechecker.env_new(ctx);
    mut scope_stdhashaliasprov := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_stdhashaliasprov, "StdHashMapGetRefAliasHolder", holder_layout_stdhashaliasprov, ctx);
    typechecker.env_register_struct(&env_stdhashaliasprov, "HashMap_Int_StdHashMapGetRefAliasHolder", map_layout_stdhashaliasprov, ctx);

    typechecker.scope_insert(scope_stdhashaliasprov, "map_stdhashaliasprov", t_map_stdhashaliasprov, ctx);
    env_stdhashaliasprov.variable_types.Insert("map_stdhashaliasprov", t_map_stdhashaliasprov);

    typechecker.scope_insert(scope_stdhashaliasprov, "key_stdhashaliasprov", t_int_stdhashaliasprov, ctx);
    env_stdhashaliasprov.variable_types.Insert("key_stdhashaliasprov", t_int_stdhashaliasprov);

    typechecker.scope_insert(scope_stdhashaliasprov, "safe_idx_stdhashaliasprov", t_node_idx_stdhashaliasprov, ctx);
    env_stdhashaliasprov.variable_types.Insert("safe_idx_stdhashaliasprov", t_node_idx_stdhashaliasprov);

    mut safe_origins_stdhashaliasprov := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_stdhashaliasprov, "safe_std_hashmap_getref_alias_root", ctx);
    env_stdhashaliasprov.variable_origins.Insert("safe_idx_stdhashaliasprov", safe_origins_stdhashaliasprov);

    mut safe_prov_stdhashaliasprov := typechecker.expression_provenance_safe_arena(t_node_idx_stdhashaliasprov, ctx);
    safe_prov_stdhashaliasprov.legacy_origins = safe_origins_stdhashaliasprov;
    typechecker.env_record_variable_provenance(&env_stdhashaliasprov, "safe_idx_stdhashaliasprov", safe_prov_stdhashaliasprov, ctx);

    mut lex_assign_stdhashaliasprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_assign_stdhashaliasprov, "std.HashMapGetRef(map_stdhashaliasprov, key_stdhashaliasprov).survivor = safe_idx_stdhashaliasprov;");
    mut parser_assign_stdhashaliasprov: parser.Parser[ctx];
    parser.init_parser(&parser_assign_stdhashaliasprov, &lex_assign_stdhashaliasprov, ctx);
    mut stmt_assign_stdhashaliasprov := parser.parse_statement(&parser_assign_stdhashaliasprov, ctx);

    typechecker.check_statement(stmt_assign_stdhashaliasprov, &env_stdhashaliasprov, scope_stdhashaliasprov, ctx);

    if len(env_stdhashaliasprov.errors) != 0 {
        os.LogStr("Error: std.HashMapGetRef selector alias fixture produced unexpected typechecker error");
        os.LogStr(env_stdhashaliasprov.errors[0].message);
        os.Exit(1);
    }

    mut lex_read_stdhashaliasprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_read_stdhashaliasprov, "map_stdhashaliasprov[key_stdhashaliasprov].survivor");
    mut parser_read_stdhashaliasprov: parser.Parser[ctx];
    parser.init_parser(&parser_read_stdhashaliasprov, &lex_read_stdhashaliasprov, ctx);
    mut expr_read_stdhashaliasprov := parser.parse_expression(&parser_read_stdhashaliasprov, 1, ctx);

    mut read_prov_stdhashaliasprov := typechecker.check_expression_with_provenance(expr_read_stdhashaliasprov, &env_stdhashaliasprov, scope_stdhashaliasprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(read_prov_stdhashaliasprov) != 1 {
        os.LogStr("Error: std.HashMapGetRef(...).field write did not alias provenance to map[key].field readback");
        os.Exit(1);
    }
    if typechecker.set_contains(read_prov_stdhashaliasprov.legacy_origins, "safe_std_hashmap_getref_alias_root", ctx) != 1 {
        os.LogStr("Error: std.HashMapGetRef(...).field alias did not preserve legacy origin");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: std.HashMapGetRef selector alias provenance metadata verified!");
}