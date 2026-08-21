import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_int_hgvfieldprov := typechecker.make_type_int();
    mut t_idx_hgvfieldprov := typechecker.make_type_index("HashMapGetValueFieldNode", "ctx", ctx);
    mut t_holder_struct_hgvfieldprov := typechecker.make_type_struct("HashMapGetValueFieldHolder", "ctx", ctx);
    mut t_ptr_int_hgvfieldprov := typechecker.make_type_pointer(t_int_hgvfieldprov, ctx);
    mut t_ptr_holder_hgvfieldprov := typechecker.make_type_pointer(t_holder_struct_hgvfieldprov, ctx);

    mut holder_layout_hgvfieldprov: typechecker.StructLayout[ctx];
    unsafe {
        holder_layout_hgvfieldprov.brand = empty[Index[str, ctx]];
        holder_layout_hgvfieldprov.fields = std.HashMapNew(ctx);
    }
    holder_layout_hgvfieldprov.fields.Insert("survivor", t_idx_hgvfieldprov);

    mut map_layout_hgvfieldprov: typechecker.StructLayout[ctx];
    unsafe {
        map_layout_hgvfieldprov.brand = empty[Index[str, ctx]];
        map_layout_hgvfieldprov.fields = std.HashMapNew(ctx);
    }
    map_layout_hgvfieldprov.fields.Insert("keys", t_ptr_int_hgvfieldprov);
    map_layout_hgvfieldprov.fields.Insert("values", t_ptr_holder_hgvfieldprov);

    mut t_map_hgvfieldprov := typechecker.make_type_struct("HashMap_Int_HashMapGetValueFieldHolder", "", ctx);

    mut env_hgvfieldprov := typechecker.env_new(ctx);
    mut scope_hgvfieldprov := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_hgvfieldprov, "HashMapGetValueFieldHolder", holder_layout_hgvfieldprov, ctx);
    typechecker.env_register_struct(&env_hgvfieldprov, "HashMap_Int_HashMapGetValueFieldHolder", map_layout_hgvfieldprov, ctx);
    typechecker.env_record_struct_container_kind(&env_hgvfieldprov, "HashMap_Int_HashMapGetValueFieldHolder", typechecker.typechecker_container_kind_hashmap(), ctx);

    typechecker.scope_insert(scope_hgvfieldprov, "map_hgvfieldprov", t_map_hgvfieldprov, ctx);
    env_hgvfieldprov.variable_types.Insert("map_hgvfieldprov", t_map_hgvfieldprov);

    typechecker.scope_insert(scope_hgvfieldprov, "key_hgvfieldprov", t_int_hgvfieldprov, ctx);
    env_hgvfieldprov.variable_types.Insert("key_hgvfieldprov", t_int_hgvfieldprov);

    mut safe_origins_hgvfieldprov := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_hgvfieldprov, "safe_hashmap_get_value_field_root", ctx);
    mut safe_field_prov_hgvfieldprov := typechecker.expression_provenance_safe_arena(t_idx_hgvfieldprov, ctx);
    safe_field_prov_hgvfieldprov.legacy_origins = safe_origins_hgvfieldprov;
    typechecker.env_record_field_provenance(&env_hgvfieldprov, "map_hgvfieldprov[key_hgvfieldprov].survivor", safe_field_prov_hgvfieldprov, ctx);
    env_hgvfieldprov.checked_results.Insert("map_hgvfieldprov.Get(key_hgvfieldprov)", 1);

    mut lex_safe_hgvfieldprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_safe_hgvfieldprov, "map_hgvfieldprov.Get(key_hgvfieldprov).Val.survivor");
    mut parser_safe_hgvfieldprov: parser.Parser[ctx];
    parser.init_parser(&parser_safe_hgvfieldprov, &lex_safe_hgvfieldprov, ctx);
    mut expr_safe_hgvfieldprov := parser.parse_expression(&parser_safe_hgvfieldprov, 1, ctx);

    mut safe_read_prov_hgvfieldprov := typechecker.check_expression_with_provenance(expr_safe_hgvfieldprov, &env_hgvfieldprov, scope_hgvfieldprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(safe_read_prov_hgvfieldprov) != 1 {
        os.LogStr("Error: HashMap.Get(key).Val.field did not preserve safe field provenance");
        os.Exit(1);
    }
    if typechecker.set_contains(safe_read_prov_hgvfieldprov.legacy_origins, "safe_hashmap_get_value_field_root", ctx) != 1 {
        os.LogStr("Error: HashMap.Get(key).Val.field did not preserve safe field origin");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_hgvfieldprov, "map_raw_hgvfieldprov", t_map_hgvfieldprov, ctx);
    env_hgvfieldprov.variable_types.Insert("map_raw_hgvfieldprov", t_map_hgvfieldprov);

    typechecker.scope_insert(scope_hgvfieldprov, "key_raw_hgvfieldprov", t_int_hgvfieldprov, ctx);
    env_hgvfieldprov.variable_types.Insert("key_raw_hgvfieldprov", t_int_hgvfieldprov);

    mut raw_origins_hgvfieldprov := typechecker.set_init(ctx);
    typechecker.set_add(raw_origins_hgvfieldprov, "raw_hashmap_get_value_field_root", ctx);
    mut raw_field_prov_hgvfieldprov := typechecker.expression_provenance_raw_derived(t_idx_hgvfieldprov, ctx);
    raw_field_prov_hgvfieldprov.legacy_origins = raw_origins_hgvfieldprov;
    typechecker.env_record_field_provenance(&env_hgvfieldprov, "map_raw_hgvfieldprov[key_raw_hgvfieldprov].survivor", raw_field_prov_hgvfieldprov, ctx);
    env_hgvfieldprov.checked_results.Insert("map_raw_hgvfieldprov.Get(key_raw_hgvfieldprov)", 1);

    mut lex_raw_hgvfieldprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_raw_hgvfieldprov, "map_raw_hgvfieldprov.Get(key_raw_hgvfieldprov).Val.survivor");
    mut parser_raw_hgvfieldprov: parser.Parser[ctx];
    parser.init_parser(&parser_raw_hgvfieldprov, &lex_raw_hgvfieldprov, ctx);
    mut expr_raw_hgvfieldprov := parser.parse_expression(&parser_raw_hgvfieldprov, 1, ctx);

    mut raw_read_prov_hgvfieldprov := typechecker.check_expression_with_provenance(expr_raw_hgvfieldprov, &env_hgvfieldprov, scope_hgvfieldprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(raw_read_prov_hgvfieldprov) == 1 {
        os.LogStr("Error: HashMap.Get(key).Val.field incorrectly allowed safe branding from raw field provenance");
        os.Exit(1);
    }
    if typechecker.expression_provenance_is_raw_or_sandbox_derived(raw_read_prov_hgvfieldprov) != 1 {
        os.LogStr("Error: HashMap.Get(key).Val.field did not preserve raw field provenance");
        os.Exit(1);
    }

    typechecker.scope_insert(scope_hgvfieldprov, "map_sandbox_hgvfieldprov", t_map_hgvfieldprov, ctx);
    env_hgvfieldprov.variable_types.Insert("map_sandbox_hgvfieldprov", t_map_hgvfieldprov);

    typechecker.scope_insert(scope_hgvfieldprov, "key_sandbox_hgvfieldprov", t_int_hgvfieldprov, ctx);
    env_hgvfieldprov.variable_types.Insert("key_sandbox_hgvfieldprov", t_int_hgvfieldprov);

    mut sandbox_origins_hgvfieldprov := typechecker.set_init(ctx);
    typechecker.set_add(sandbox_origins_hgvfieldprov, "sandbox_hashmap_get_value_field_root", ctx);
    mut sandbox_field_prov_hgvfieldprov := typechecker.expression_provenance_sandbox_derived(t_idx_hgvfieldprov, ctx);
    sandbox_field_prov_hgvfieldprov.legacy_origins = sandbox_origins_hgvfieldprov;
    typechecker.env_record_field_provenance(&env_hgvfieldprov, "map_sandbox_hgvfieldprov[key_sandbox_hgvfieldprov].survivor", sandbox_field_prov_hgvfieldprov, ctx);
    env_hgvfieldprov.checked_results.Insert("map_sandbox_hgvfieldprov.Get(key_sandbox_hgvfieldprov)", 1);

    mut lex_sandbox_hgvfieldprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_sandbox_hgvfieldprov, "map_sandbox_hgvfieldprov.Get(key_sandbox_hgvfieldprov).Val.survivor");
    mut parser_sandbox_hgvfieldprov: parser.Parser[ctx];
    parser.init_parser(&parser_sandbox_hgvfieldprov, &lex_sandbox_hgvfieldprov, ctx);
    mut expr_sandbox_hgvfieldprov := parser.parse_expression(&parser_sandbox_hgvfieldprov, 1, ctx);

    mut sandbox_read_prov_hgvfieldprov := typechecker.check_expression_with_provenance(expr_sandbox_hgvfieldprov, &env_hgvfieldprov, scope_hgvfieldprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(sandbox_read_prov_hgvfieldprov) == 1 {
        os.LogStr("Error: HashMap.Get(key).Val.field incorrectly allowed safe branding from sandbox field provenance");
        os.Exit(1);
    }
    if typechecker.expression_provenance_is_raw_or_sandbox_derived(sandbox_read_prov_hgvfieldprov) != 1 {
        os.LogStr("Error: HashMap.Get(key).Val.field did not preserve sandbox field provenance");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: HashMap.Get value field provenance metadata verified!");
}
