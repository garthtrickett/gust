import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func parse_expr_container_flow(src: str, ctx: &Arena) Index[ast.Expression[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_expression(&p, 1, ctx);
}

func parse_stmt_container_flow(src: str, ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_statement(&p, ctx);
}

func assert_raw_container_flow(prov: typechecker.ExpressionProvenance[ctx], origin: str, label: str, message: str, ctx: &Arena) {
    if typechecker.step51g_expression_provenance_is_raw_derived(prov) != 1 {
        os.LogStr(std.Concat("Error: raw container flow did not preserve raw-derived provenance for ", message));
        os.Exit(1);
    }
    if typechecker.set_contains(prov.legacy_origins, origin, ctx) != 1 {
        os.LogStr(std.Concat("Error: raw container flow did not preserve legacy origin for ", message));
        os.Exit(1);
    }
    if std.str_eq(label, "") == 0 {
        if typechecker.set_contains(prov.legacy_origins, label, ctx) != 1 {
            os.LogStr(std.Concat("Error: raw container flow did not stamp container label for ", message));
            os.Exit(1);
        }
    }
}

func assert_sandbox_container_flow(prov: typechecker.ExpressionProvenance[ctx], origin: str, label: str, message: str, ctx: &Arena) {
    if typechecker.step51g_expression_provenance_is_sandbox_derived(prov) != 1 {
        os.LogStr(std.Concat("Error: sandbox container flow did not preserve sandbox-derived provenance for ", message));
        os.Exit(1);
    }
    if typechecker.set_contains(prov.legacy_origins, origin, ctx) != 1 {
        os.LogStr(std.Concat("Error: sandbox container flow did not preserve legacy origin for ", message));
        os.Exit(1);
    }
    if std.str_eq(label, "") == 0 {
        if typechecker.set_contains(prov.legacy_origins, label, ctx) != 1 {
            os.LogStr(std.Concat("Error: sandbox container flow did not stamp container label for ", message));
            os.Exit(1);
        }
    }
}

func register_vector_int_container_flow(env: *typechecker.TypeEnvironment[ctx], name: str, ctx: &Arena) ast.Type[ctx] {
    mut t_int := typechecker.make_type_int();
    mut t_ptr_int := typechecker.make_type_pointer(t_int, ctx);
    mut vector_layout: typechecker.StructLayout[ctx];
    unsafe {
        vector_layout.brand = empty[Index[str, ctx]];
        vector_layout.fields = std.HashMapNew(ctx);
    }
    vector_layout.fields.Insert("data", t_ptr_int);
    typechecker.env_register_struct(env, name, vector_layout, ctx);
    return typechecker.make_type_struct(name, "", ctx);
}

func register_hashmap_int_int_container_flow(env: *typechecker.TypeEnvironment[ctx], name: str, ctx: &Arena) ast.Type[ctx] {
    mut t_int := typechecker.make_type_int();
    mut t_ptr_int := typechecker.make_type_pointer(t_int, ctx);
    mut map_layout: typechecker.StructLayout[ctx];
    unsafe {
        map_layout.brand = empty[Index[str, ctx]];
        map_layout.fields = std.HashMapNew(ctx);
    }
    map_layout.fields.Insert("keys", t_ptr_int);
    map_layout.fields.Insert("values", t_ptr_int);
    typechecker.env_register_struct(env, name, map_layout, ctx);
    return typechecker.make_type_struct(name, "", ctx);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut t_int := typechecker.make_type_int();

    mut t_vector_raw := register_vector_int_container_flow(&env, "Vector_Int_RawSandboxContainerFlow", ctx);
    typechecker.scope_insert(scope, "values_raw_container_flow", t_vector_raw, ctx);
    env.variable_types.Insert("values_raw_container_flow", t_vector_raw);

    typechecker.scope_insert(scope, "i_container_flow", t_int, ctx);
    env.variable_types.Insert("i_container_flow", t_int);

    typechecker.scope_insert(scope, "raw_container_source", t_int, ctx);
    env.variable_types.Insert("raw_container_source", t_int);
    mut raw_source_prov := typechecker.expression_provenance_raw_derived(t_int, ctx);
    typechecker.set_add(raw_source_prov.legacy_origins, "raw_container_flow_root", ctx);
    typechecker.env_record_variable_provenance(&env, "raw_container_source", raw_source_prov, ctx);

    env.in_unsafe_block = 1;
    mut raw_index_assign_stmt := parse_stmt_container_flow("values_raw_container_flow[i_container_flow] = raw_container_source;", ctx);
    typechecker.check_statement(raw_index_assign_stmt, &env, scope, ctx);
    env.in_unsafe_block = 0;

    mut raw_index_expr := parse_expr_container_flow("values_raw_container_flow[i_container_flow]", ctx);
    mut raw_index_prov := typechecker.check_expression_with_provenance(raw_index_expr, &env, scope, ctx);
    assert_raw_container_flow(raw_index_prov, "raw_container_flow_root", "container.element:index", "indexed assignment/readback", ctx);

    mut raw_ref_expr := parse_expr_container_flow("values_raw_container_flow.GetRef(i_container_flow)", ctx);
    mut raw_ref_prov := typechecker.check_expression_with_provenance(raw_ref_expr, &env, scope, ctx);
    assert_raw_container_flow(raw_ref_prov, "raw_container_flow_root", "container.element:GetRef", "GetRef readback", ctx);

    mut t_vector_sandbox := register_vector_int_container_flow(&env, "Vector_Int_SandboxContainerFlow", ctx);
    typechecker.scope_insert(scope, "values_sandbox_container_flow", t_vector_sandbox, ctx);
    env.variable_types.Insert("values_sandbox_container_flow", t_vector_sandbox);

    typechecker.scope_insert(scope, "sandbox_container_source", t_int, ctx);
    env.variable_types.Insert("sandbox_container_source", t_int);
    mut sandbox_source_prov := typechecker.expression_provenance_sandbox_derived(t_int, ctx);
    typechecker.set_add(sandbox_source_prov.legacy_origins, "sandbox_container_flow_root", ctx);
    typechecker.env_record_variable_provenance(&env, "sandbox_container_source", sandbox_source_prov, ctx);

    mut sandbox_set_stmt := parse_stmt_container_flow("values_sandbox_container_flow.Set(i_container_flow, sandbox_container_source);", ctx);
    typechecker.check_statement(sandbox_set_stmt, &env, scope, ctx);

    mut sandbox_index_expr := parse_expr_container_flow("values_sandbox_container_flow[i_container_flow]", ctx);
    mut sandbox_index_prov := typechecker.check_expression_with_provenance(sandbox_index_expr, &env, scope, ctx);
    assert_sandbox_container_flow(sandbox_index_prov, "sandbox_container_flow_root", "container.element:index", "Vector.Set indexed readback", ctx);

    mut t_map := register_hashmap_int_int_container_flow(&env, "HashMap_Int_Int_RawSandboxContainerFlow", ctx);
    typechecker.scope_insert(scope, "map_container_flow", t_map, ctx);
    env.variable_types.Insert("map_container_flow", t_map);

    typechecker.scope_insert(scope, "key_container_flow", t_int, ctx);
    env.variable_types.Insert("key_container_flow", t_int);

    mut map_set_stmt := parse_stmt_container_flow("map_container_flow.Set(key_container_flow, sandbox_container_source);", ctx);
    typechecker.check_statement(map_set_stmt, &env, scope, ctx);

    mut map_get_expr := parse_expr_container_flow("map_container_flow.Get(key_container_flow).Val", ctx);
    mut map_get_prov := typechecker.check_expression_with_provenance(map_get_expr, &env, scope, ctx);
    assert_sandbox_container_flow(map_get_prov, "sandbox_container_flow_root", "container.element:HashMap.Get", "HashMap.Get value readback", ctx);

    if len(env.errors) != 0 {
        os.LogStr("Error: raw/sandbox container flow fixture produced unexpected typechecker error");
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }

    os.LogStr("SUCCESS: step51_raw_sandbox_provenance_container_flow");
}