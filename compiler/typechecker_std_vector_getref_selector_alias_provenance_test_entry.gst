import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut t_int_stdvecaliasprov := typechecker.make_type_int();
    mut t_node_idx_stdvecaliasprov := typechecker.make_type_index("StdVectorGetRefAliasNode", "ctx", ctx);
    mut t_holder_struct_stdvecaliasprov := typechecker.make_type_struct("StdVectorGetRefAliasHolder", "ctx", ctx);
    mut t_ptr_holder_stdvecaliasprov := typechecker.make_type_pointer(t_holder_struct_stdvecaliasprov, ctx);

    mut holder_layout_stdvecaliasprov: typechecker.StructLayout[ctx];
    unsafe {
        holder_layout_stdvecaliasprov.brand = empty[Index[str, ctx]];
        holder_layout_stdvecaliasprov.fields = std.HashMapNew(ctx);
    }
    holder_layout_stdvecaliasprov.fields.Insert("survivor", t_node_idx_stdvecaliasprov);

    mut vector_layout_stdvecaliasprov: typechecker.StructLayout[ctx];
    unsafe {
        vector_layout_stdvecaliasprov.brand = empty[Index[str, ctx]];
        vector_layout_stdvecaliasprov.fields = std.HashMapNew(ctx);
    }
    vector_layout_stdvecaliasprov.fields.Insert("data", t_ptr_holder_stdvecaliasprov);

    mut t_vector_stdvecaliasprov := typechecker.make_type_struct("Vector_StdVectorGetRefAliasHolder", "", ctx);

    mut env_stdvecaliasprov := typechecker.env_new(ctx);
    mut scope_stdvecaliasprov := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    typechecker.env_register_struct(&env_stdvecaliasprov, "StdVectorGetRefAliasHolder", holder_layout_stdvecaliasprov, ctx);
    typechecker.env_register_struct(&env_stdvecaliasprov, "Vector_StdVectorGetRefAliasHolder", vector_layout_stdvecaliasprov, ctx);
    typechecker.env_record_struct_container_kind(&env_stdvecaliasprov, "Vector_StdVectorGetRefAliasHolder", typechecker.typechecker_container_kind_vector(), ctx);

    typechecker.scope_insert(scope_stdvecaliasprov, "values_stdvecaliasprov", t_vector_stdvecaliasprov, ctx);
    env_stdvecaliasprov.variable_types.Insert("values_stdvecaliasprov", t_vector_stdvecaliasprov);

    typechecker.scope_insert(scope_stdvecaliasprov, "i_stdvecaliasprov", t_int_stdvecaliasprov, ctx);
    env_stdvecaliasprov.variable_types.Insert("i_stdvecaliasprov", t_int_stdvecaliasprov);

    typechecker.scope_insert(scope_stdvecaliasprov, "safe_idx_stdvecaliasprov", t_node_idx_stdvecaliasprov, ctx);
    env_stdvecaliasprov.variable_types.Insert("safe_idx_stdvecaliasprov", t_node_idx_stdvecaliasprov);

    mut safe_origins_stdvecaliasprov := typechecker.set_init(ctx);
    typechecker.set_add(safe_origins_stdvecaliasprov, "safe_std_vector_getref_alias_root", ctx);
    env_stdvecaliasprov.variable_origins.Insert("safe_idx_stdvecaliasprov", safe_origins_stdvecaliasprov);

    mut safe_prov_stdvecaliasprov := typechecker.expression_provenance_safe_arena(t_node_idx_stdvecaliasprov, ctx);
    safe_prov_stdvecaliasprov.legacy_origins = safe_origins_stdvecaliasprov;
    typechecker.env_record_variable_provenance(&env_stdvecaliasprov, "safe_idx_stdvecaliasprov", safe_prov_stdvecaliasprov, ctx);

    mut lex_assign_stdvecaliasprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_assign_stdvecaliasprov, "std.VectorGetRef(values_stdvecaliasprov, i_stdvecaliasprov).survivor = safe_idx_stdvecaliasprov;");
    mut parser_assign_stdvecaliasprov: parser.Parser[ctx];
    parser.init_parser(&parser_assign_stdvecaliasprov, &lex_assign_stdvecaliasprov, ctx);
    mut stmt_assign_stdvecaliasprov := parser.parse_statement(&parser_assign_stdvecaliasprov, ctx);

    typechecker.check_statement(stmt_assign_stdvecaliasprov, &env_stdvecaliasprov, scope_stdvecaliasprov, ctx);

    if len(env_stdvecaliasprov.errors) != 0 {
        os.LogStr("Error: std.VectorGetRef selector alias fixture produced unexpected typechecker error");
        os.LogStr(env_stdvecaliasprov.errors[0].message);
        os.Exit(1);
    }

    mut lex_read_stdvecaliasprov: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_read_stdvecaliasprov, "values_stdvecaliasprov[i_stdvecaliasprov].survivor");
    mut parser_read_stdvecaliasprov: parser.Parser[ctx];
    parser.init_parser(&parser_read_stdvecaliasprov, &lex_read_stdvecaliasprov, ctx);
    mut expr_read_stdvecaliasprov := parser.parse_expression(&parser_read_stdvecaliasprov, 1, ctx);

    mut read_prov_stdvecaliasprov := typechecker.check_expression_with_provenance(expr_read_stdvecaliasprov, &env_stdvecaliasprov, scope_stdvecaliasprov, ctx);
    if typechecker.expression_provenance_allows_safe_branding(read_prov_stdvecaliasprov) != 1 {
        os.LogStr("Error: std.VectorGetRef(...).field write did not alias provenance to values[index].field readback");
        os.Exit(1);
    }
    if typechecker.set_contains(read_prov_stdvecaliasprov.legacy_origins, "safe_std_vector_getref_alias_root", ctx) != 1 {
        os.LogStr("Error: std.VectorGetRef(...).field alias did not preserve legacy origin");
        os.Exit(1);
    }

    os.LogStr("SUCCESS: std.VectorGetRef selector alias provenance metadata verified!");
}
