import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    // Test set_init
    mut set1 := typechecker.set_init(ctx);
    
    // Test set_add
    typechecker.set_add(set1, "origin_a", ctx);
    typechecker.set_add(set1, "origin_b", ctx);

    // Test set_contains
    if typechecker.set_contains(set1, "origin_a", ctx) {
        os.LogStr("set1 has origin_a");
    } else {
        os.LogStr("set1 missing origin_a");
    }

    if typechecker.set_contains(set1, "origin_c", ctx) {
        os.LogStr("set1 has origin_c");
    } else {
        os.LogStr("set1 missing origin_c");
    }

    // Test set_union
    mut set2 := typechecker.set_init(ctx);
    typechecker.set_add(set2, "origin_c", ctx);
    typechecker.set_add(set2, "origin_d", ctx);

    typechecker.set_union(set1, set2, ctx);

    if typechecker.set_contains(set1, "origin_c", ctx) {
        os.LogStr("set1 now has origin_c");
    } else {
        os.LogStr("set1 still missing origin_c");
    }

    if typechecker.set_contains(set1, "origin_d", ctx) == 1 {
        os.LogStr("set1 now has origin_d");
    } else {
        os.LogStr("set1 still missing origin_d");
    }

    // --- PART 2: Recursive Expression Origin Extraction Tests ---
    mut env := typechecker.env_new(ctx);
    
    // Pre-register some variables/origins in the environment
    mut v_orig1 := typechecker.set_init(ctx);
    typechecker.set_add(v_orig1, "my_root", ctx);
    env.variable_origins.Insert(std.Clone(ctx, "my_var"), v_orig1);

    // Pre-register a dummy function std.Format returning a Str (which is a view type)
    mut sig: typechecker.FunctionSignature[ctx];
    sig.param_names = std.VectorNew(ctx);
    sig.params = std.VectorNew(ctx);
    sig.return_type.tag = 5; // Str
    typechecker.env_register_function(&env, "std_Format", sig, ctx);

    // Initialize Lexer & Parser for: "my_var.field[index_val]"
    mut l1: lexer.Lexer[ctx];
    lexer.init_lexer(&l1, "my_var.field[index_val]");
    mut p1: parser.Parser[ctx];
    parser.init_parser(&p1, &l1, ctx);
    mut expr1 := parser.parse_expression(&p1, 1, ctx);

    mut origs1 := typechecker.get_expression_origins(expr1, &env, ctx);
    if typechecker.set_contains(origs1, "my_root", ctx) == 1 {
        os.LogStr("expr1 correctly resolved to my_root");
    } else {
        os.LogStr("expr1 failed to resolve to my_root");
    }

    // Initialize Lexer & Parser for: "std.Format(\"Item %d\", my_var)"
    mut l2: lexer.Lexer[ctx];
    lexer.init_lexer(&l2, "std.Format(\"Item %d\", my_var)");
    mut p2: parser.Parser[ctx];
    parser.init_parser(&p2, &l2, ctx);
    mut expr2 := parser.parse_expression(&p2, 1, ctx);

    mut origs2 := typechecker.get_expression_origins(expr2, &env, ctx);
    if typechecker.set_contains(origs2, "scratch", ctx) == 1 {
        os.LogStr("expr2 correctly identified scratch");
    } else {
        os.LogStr("expr2 failed to identify scratch");
    }

    // --- PART 3: Expression Typechecker Verification Tests ---
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    // Case 1: Variable Origin Invalidated Check
    mut t_int: ast.Type[ctx];
    t_int.tag = 0; // Int
    typechecker.scope_insert(scope, "var_a", t_int, ctx);

    mut orig_a := typechecker.set_init(ctx);
    typechecker.set_add(orig_a, "origin_x", ctx);
    env.variable_origins.Insert(std.Clone(ctx, "var_a"), orig_a);

    env.moved_vars.Insert(std.Clone(ctx, "origin_x"), 1);

    mut l3: lexer.Lexer[ctx];
    lexer.init_lexer(&l3, "var_a");
    mut p3: parser.Parser[ctx];
    parser.init_parser(&p3, &l3, ctx);
    mut expr3 := parser.parse_expression(&p3, 1, ctx);

    typechecker.check_expression(expr3, &env, scope, ctx);

    mut has_origin_err := 0;
    mut j := 0;
    while j < len(env.errors) { 
        mut err := env.errors[j];
        if std.str_find(err.message, "origin invalidated") != 0 - 1 {
            has_origin_err = 1;
        }
        j = j + 1;
    }

    if has_origin_err == 1 {
        os.LogStr("expr3 correctly flagged origin_x invalidation");
    } else {
        os.LogStr("expr3 failed to flag origin_x invalidation");
    }

    // Case 2: Allocator Moved Or Freed Check
    mut t_index: ast.Type[ctx];
    t_index.tag = 7; // Index
    t_index.Index.struct_name = std.Clone(ctx, "Node");
    mut brand_idx: Index[str, ctx] := empty[Index[str, ctx]];
    unsafe {
        brand_idx = os.ArenaAlloc(ctx) as Index[str, ctx];
        mut brand_ptr := &ctx[brand_idx] as *str;
        *brand_ptr = "ctx_brand";
    }
    t_index.Index.brand = brand_idx;
    typechecker.scope_insert(scope, "var_b", t_index, ctx);

    env.moved_vars.Insert(std.Clone(ctx, "ctx_brand"), 1);

    mut l4: lexer.Lexer[ctx];
    lexer.init_lexer(&l4, "var_b");
    mut p4: parser.Parser[ctx];
    parser.init_parser(&p4, &l4, ctx);
    mut expr4 := parser.parse_expression(&p4, 1, ctx);

    typechecker.check_expression(expr4, &env, scope, ctx);

    mut has_brand_err := 0;
    mut k := 0;
    while k < len(env.errors) { 
        mut err := env.errors[k];
        if std.str_find(err.message, "Allocator moved or freed") != 0 - 1 {
            has_brand_err = 1;
        }
        k = k + 1;
    }

    if has_brand_err == 1 {
        os.LogStr("expr4 correctly flagged ctx_brand invalidation");
    } else {
        os.LogStr("expr4 failed to flag ctx_brand invalidation");
    }

    // Case 3: Use Of Moved Variable Check
    typechecker.scope_insert(scope, "var_c", t_int, ctx);
    env.moved_vars.Insert(std.Clone(ctx, "var_c"), 1);

    mut l5: lexer.Lexer[ctx];
    lexer.init_lexer(&l5, "var_c");
    mut p5: parser.Parser[ctx];
    parser.init_parser(&p5, &l5, ctx);
    mut expr5 := parser.parse_expression(&p5, 1, ctx);

    typechecker.check_expression(expr5, &env, scope, ctx);

    mut has_move_err := 0;
    mut m := 0;
    while m < len(env.errors) { 
        mut err := env.errors[m];
        if std.str_find(err.message, "Use of moved variable") != 0 - 1 {
            has_move_err = 1;
        }
        m = m + 1;
    }

    if has_move_err == 1 {
        os.LogStr("expr5 correctly flagged var_c move");
    } else {
        os.LogStr("expr5 failed to flag var_c move");
    }

    // --- PART 4: typechecker_extract_ok_checked_variables Tests ---
    // Expression: cond && result.Ok
    mut l6: lexer.Lexer[ctx];
    lexer.init_lexer(&l6, "cond && result.Ok");
    mut p6: parser.Parser[ctx];
    parser.init_parser(&p6, &l6, ctx);
    mut expr6 := parser.parse_expression(&p6, 1, ctx);

    mut checked_map: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
    typechecker.typechecker_extract_ok_checked_variables(expr6, &checked_map, ctx);

    if checked_map.Get("result").Ok == 1 {
        os.LogStr("typechecker_extract_ok_checked_variables correctly extracted result");
    } else {
        os.LogStr("typechecker_extract_ok_checked_variables failed to extract result");
    }

    // Expression: cond || result.Ok
    mut l7: lexer.Lexer[ctx];
    lexer.init_lexer(&l7, "cond || result.Ok");
    mut p7: parser.Parser[ctx];
    parser.init_parser(&p7, &l7, ctx);
    mut expr7 := parser.parse_expression(&p7, 1, ctx);

    mut checked_map2: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
    typechecker.typechecker_extract_ok_checked_variables(expr7, &checked_map2, ctx);

    if checked_map2.Get("result").Ok == 0 {
        os.LogStr("typechecker_extract_ok_checked_variables correctly ignored OR operator");
    } else {
        os.LogStr("typechecker_extract_ok_checked_variables incorrectly extracted result under OR");
    }

    // Test Step 1 & 2: Guard Statement Typechecking & Wrapper Validation
    
    // Scenario A: Guard statement with integer RHS (should report TypeMismatch error)
    mut l_guard_tc_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_guard_tc_test, "guard mut x := 42 else { return; }");
    mut p_guard_tc_test: parser.Parser[ctx];
    parser.init_parser(&p_guard_tc_test, &l_guard_tc_test, ctx);
    mut prog_guard_tc_test := parser.parse_program(&p_guard_tc_test, ctx);
    unsafe {
        mut statements_vec := &ctx[prog_guard_tc_test.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut guard_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx); 
        ctx[guard_stmt_idx] = (*statements_vec)[0];

        mut env_tc_test := typechecker.env_new(ctx);
        mut scope_tc_test := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

        // Mock expected return type to allow top-level return statement inside else block
        mut t_void: ast.Type[ctx]; t_void.tag = 3; // Void
        env_tc_test.expected_return_type = os.ArenaAlloc(ctx);
        ctx[env_tc_test.expected_return_type] = t_void;

        mut result := typechecker.check_statement(guard_stmt_idx, &env_tc_test, scope_tc_test, ctx);
        
        mut value_expr := ctx[guard_stmt_idx].Guard.value;
        mut value_span := parser.get_expression_span(value_expr, ctx);

        mut prefix := "";
        mut found_idx := 0 - 1;
        mut i := 0;
        while i < len(env_tc_test.resolved_types_nested) {
            mut entry := env_tc_test.resolved_types_nested[i];
            if std.str_eq(entry.prefix, prefix) {
                found_idx = i;
                i = len(env_tc_test.resolved_types_nested);
            }
            i = i + 1;
        }

        if found_idx != 0 - 1 {
            mut entry_ref := &env_tc_test.resolved_types_nested[found_idx];
            mut found_type := 0;
            mut j := 0;
            while j < len((*entry_ref).types) {
                mut t_entry := (*entry_ref).types[j];
                if t_entry.start_offset == value_span.start.offset && t_entry.end_offset == value_span.end.offset {
                    found_type = 1;
                    j = len((*entry_ref).types);
                }
                j = j + 1;
            }
        }
        
        os.LogInt(len(env_tc_test.errors)); // Expected: 1 (Since RHS is Int, not a fallible wrapper)
        if len(env_tc_test.errors) > 0 {
            os.LogStr(env_tc_test.errors[0].message); // Expected message containing fallible wrapper
        }
    }

    // Scenario B: Guard statement with valid LookupResult RHS (should succeed)
    mut l_guard_tc_test2: lexer.Lexer[ctx];
    lexer.init_lexer(&l_guard_tc_test2, "guard mut x := res_val else { return; }");
    mut p_guard_tc_test2: parser.Parser[ctx];
    parser.init_parser(&p_guard_tc_test2, &l_guard_tc_test2, ctx);
    mut prog_guard_tc_test2 := parser.parse_program(&p_guard_tc_test2, ctx);
    unsafe {
        mut statements_vec := &ctx[prog_guard_tc_test2.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut guard_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[guard_stmt_idx] = (*statements_vec)[0];

        mut env_tc_test := typechecker.env_new(ctx);
        mut scope_tc_test := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

        // Mock expected return type to allow top-level return statement inside else block
        mut t_void: ast.Type[ctx]; t_void.tag = 3; // Void
        env_tc_test.expected_return_type = os.ArenaAlloc(ctx);
        ctx[env_tc_test.expected_return_type] = t_void;

        // Register custom fallible wrapper
        mut fields: std.HashMap[str, ast.Type[ctx], ctx] := std.HashMapNew(ctx);
        mut t_int: ast.Type[ctx]; t_int.tag = 0; // Int
        fields.Insert("Ok", t_int);
        
        mut t_payload: ast.Type[ctx]; t_payload.tag = 8; // Struct
        t_payload.Struct.struct_name = "os_Dir_ctx";
        t_payload.Struct.brand = empty[Index[str, ctx]];
        fields.Insert("Val", t_payload);

        mut layout: typechecker.StructLayout[ctx];
        layout.brand = empty[Index[str, ctx]];
        layout.fields = fields;
        typechecker.env_register_struct(&env_tc_test, "LookupResult_os_Dir_ctx", layout, ctx);

        // Register variable res_val of type LookupResult_os_Dir_ctx
        mut t_wrapper: ast.Type[ctx];
        t_wrapper.tag = 8; // Struct
        t_wrapper.Struct.struct_name = "LookupResult_os_Dir_ctx";
        t_wrapper.Struct.brand = empty[Index[str, ctx]];
        env_tc_test.variable_types.Insert("res_val", t_wrapper);
        typechecker.scope_insert(scope_tc_test, "res_val", t_wrapper, ctx);

        mut result := typechecker.check_statement(guard_stmt_idx, &env_tc_test, scope_tc_test, ctx);
        if result.tag == 0 { // Ok
            os.LogStr("Scenario B check: Ok");
            os.LogInt(len(env_tc_test.errors)); // Expected: 0
        } else {
            os.LogStr("Scenario B check: Err");
        }
    }

    // Scenario C: Guard statement with non-diverging else block (should report TypeMismatch error)
    mut l_guard_tc_test3: lexer.Lexer[ctx];
    lexer.init_lexer(&l_guard_tc_test3, "guard mut x := res_val else { mut y := 10; }");
    mut p_guard_tc_test3: parser.Parser[ctx];
    parser.init_parser(&p_guard_tc_test3, &l_guard_tc_test3, ctx);
    mut prog_guard_tc_test3 := parser.parse_program(&p_guard_tc_test3, ctx);
    unsafe {
        mut statements_vec := &ctx[prog_guard_tc_test3.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut guard_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[guard_stmt_idx] = (*statements_vec)[0];

        mut env_tc_test := typechecker.env_new(ctx);
        mut scope_tc_test := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

        // Register custom fallible wrapper
        mut fields: std.HashMap[str, ast.Type[ctx], ctx] := std.HashMapNew(ctx);
        mut t_int: ast.Type[ctx]; t_int.tag = 0; // Int
        fields.Insert("Ok", t_int);
        
        mut t_payload: ast.Type[ctx]; t_payload.tag = 8; // Struct
        t_payload.Struct.struct_name = "os_Dir_ctx";
        t_payload.Struct.brand = empty[Index[str, ctx]];
        fields.Insert("Val", t_payload);

        mut layout: typechecker.StructLayout[ctx];
        layout.brand = empty[Index[str, ctx]];
        layout.fields = fields;
        typechecker.env_register_struct(&env_tc_test, "LookupResult_os_Dir_ctx", layout, ctx);

        // Register variable res_val of type LookupResult_os_Dir_ctx
        mut t_wrapper: ast.Type[ctx];
        t_wrapper.tag = 8; // Struct
        t_wrapper.Struct.struct_name = "LookupResult_os_Dir_ctx";
        t_wrapper.Struct.brand = empty[Index[str, ctx]];
        env_tc_test.variable_types.Insert("res_val", t_wrapper);
        typechecker.scope_insert(scope_tc_test, "res_val", t_wrapper, ctx);

        mut result := typechecker.check_statement(guard_stmt_idx, &env_tc_test, scope_tc_test, ctx);
        os.LogInt(len(env_tc_test.errors)); // Expected: 1 (Since else block doesn't diverge)
        if len(env_tc_test.errors) > 0 {
            os.LogStr(env_tc_test.errors[0].message); // Expected message containing diverge
        }
    }

    // Scenario D: Guard statement with diverging else block containing os.Exit (should succeed)
    mut l_guard_tc_test4: lexer.Lexer[ctx];
    lexer.init_lexer(&l_guard_tc_test4, "guard mut x := res_val else { os.Exit(1); }");
    mut p_guard_tc_test4: parser.Parser[ctx];
    parser.init_parser(&p_guard_tc_test4, &l_guard_tc_test4, ctx);
    mut prog_guard_tc_test4 := parser.parse_program(&p_guard_tc_test4, ctx);
    unsafe {
        mut statements_vec := &ctx[prog_guard_tc_test4.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut guard_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[guard_stmt_idx] = (*statements_vec)[0];

        mut env_tc_test := typechecker.env_new(ctx);
        mut scope_tc_test := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

        // Register custom fallible wrapper
        mut fields: std.HashMap[str, ast.Type[ctx], ctx] := std.HashMapNew(ctx);
        mut t_int: ast.Type[ctx]; t_int.tag = 0; // Int
        fields.Insert("Ok", t_int);
        
        mut t_payload: ast.Type[ctx]; t_payload.tag = 8; // Struct
        t_payload.Struct.struct_name = "os_Dir_ctx";
        t_payload.Struct.brand = empty[Index[str, ctx]];
        fields.Insert("Val", t_payload);

        mut layout: typechecker.StructLayout[ctx];
        layout.brand = empty[Index[str, ctx]];
        layout.fields = fields;
        typechecker.env_register_struct(&env_tc_test, "LookupResult_os_Dir_ctx", layout, ctx);

        // Register variable res_val of type LookupResult_os_Dir_ctx
        mut t_wrapper: ast.Type[ctx];
        t_wrapper.tag = 8; // Struct
        t_wrapper.Struct.struct_name = "LookupResult_os_Dir_ctx";
        t_wrapper.Struct.brand = empty[Index[str, ctx]];
        env_tc_test.variable_types.Insert("res_val", t_wrapper);
        typechecker.scope_insert(scope_tc_test, "res_val", t_wrapper, ctx);

        mut result := typechecker.check_statement(guard_stmt_idx, &env_tc_test, scope_tc_test, ctx);
        if result.tag == 0 { // Ok
            os.LogStr("Scenario D check: Ok");
            os.LogInt(len(env_tc_test.errors)); // Expected: 0
        } else {
            os.LogStr("Scenario D check: Err");
        }
    }

    // Test Step 2: Dynamic LookupResult_ Synthesis (Step 2 Fix)
    mut env_step2 := typechecker.env_new(ctx);
    mut t_step2 := typechecker.make_type_struct("LookupResult_os_Dir_ctx", "", ctx);
    mut resolved_step2 := typechecker.env_resolve_type(&env_step2, t_step2, ctx);
    
    mut layout_lookup_step2 := env_step2.struct_registry.Get("LookupResult_os_Dir_ctx");
    if layout_lookup_step2.Ok {
        os.LogStr("LookupResult_os_Dir_ctx successfully synthesized!");
        mut val_t_lookup := layout_lookup_step2.Val.fields.Get("Val");
        if val_t_lookup.Ok {
            os.LogStr(ast.serialize_type(val_t_lookup.Val, ctx));
        }
    } else { 
        os.LogStr("LookupResult_os_Dir_ctx synthesis failed!");
    }

    // Test Step 3: Dynamic CastResult_ Synthesis (Step 3 Fix)
    mut env_step3 := typechecker.env_new(ctx);
    mut t_step3 := typechecker.make_type_struct("CastResult_MyNode_ctx", "", ctx);
    mut resolved_step3 := typechecker.env_resolve_type(&env_step3, t_step3, ctx);
    
    mut layout_lookup_step3 := env_step3.struct_registry.Get("CastResult_MyNode_ctx");
    if layout_lookup_step3.Ok { 
        os.LogStr("CastResult_MyNode_ctx successfully synthesized!");
        mut val_t_lookup := layout_lookup_step3.Val.fields.Get("Val");
        if val_t_lookup.Ok {
            os.LogStr(ast.serialize_type(val_t_lookup.Val, ctx));
        }
    } else { 
        os.LogStr("CastResult_MyNode_ctx synthesis failed!");
    }

    // Step 1: Raw Pointer Indexing Verification Test
    mut env_ptr_test := typechecker.env_new(ctx);
    mut scope_ptr_test := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    // Register a custom struct Node
    mut node_layout: typechecker.StructLayout[ctx];
    node_layout.brand = empty[Index[str, ctx]];
    node_layout.fields = std.HashMapNew(ctx);
    typechecker.env_register_struct(&env_ptr_test, "Node", node_layout, ctx);

    // Create a pointer to Node
    mut t_node_struct := typechecker.make_type_struct("Node", "", ctx);
    mut t_node_ptr := typechecker.make_type_pointer(t_node_struct, ctx);

    // Insert pointer variable 'p_node' into scope
    typechecker.scope_insert(scope_ptr_test, "p_node", t_node_ptr, ctx);

    // Parse index access 'p_node[0]'
    mut l_ptr_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_ptr_test, "p_node[0]");
    mut p_ptr_test: parser.Parser[ctx];
    parser.init_parser(&p_ptr_test, &l_ptr_test, ctx);
    mut expr_ptr_test := parser.parse_expression(&p_ptr_test, 1, ctx);

    // Check expression
    mut evaluated_ptr_t := typechecker.check_expression(expr_ptr_test, &env_ptr_test, scope_ptr_test, ctx);
    os.LogStr(ast.serialize_type(evaluated_ptr_t, ctx)); // Expected: Struct("Node", None)

    // Step 1 Verification: Test IndexAccess on RawPointer(Arena)
    mut env_step1_test := typechecker.env_new(ctx);
    mut scope_step1_test := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    // Register a custom struct MyNode
    mut my_node_layout: typechecker.StructLayout[ctx];
    my_node_layout.brand = empty[Index[str, ctx]];
    my_node_layout.fields = std.HashMapNew(ctx);
    typechecker.env_register_struct(&env_step1_test, "MyNode", my_node_layout, ctx);

    // Create ctx_var of type RawPointer(Arena)
    mut t_arena := typechecker.make_type_arena();
    mut t_arena_ptr := typechecker.make_type_pointer(t_arena, ctx);
    typechecker.scope_insert(scope_step1_test, "ctx_var", t_arena_ptr, ctx);

    // Create index variable of type Index[MyNode, ctx_var]
    mut t_index_var := typechecker.make_type_index("MyNode", "ctx_var", ctx);
    typechecker.scope_insert(scope_step1_test, "idx_var", t_index_var, ctx);

    // Parse and check "ctx_var[idx_var]"
    mut l_step1: lexer.Lexer[ctx];
    lexer.init_lexer(&l_step1, "ctx_var[idx_var]");
    mut p_step1: parser.Parser[ctx];
    parser.init_parser(&p_step1, &l_step1, ctx);
    mut expr_step1 := parser.parse_expression(&p_step1, 1, ctx);

    mut evaluated_step1_t := typechecker.check_expression(expr_step1, &env_step1_test, scope_step1_test, ctx);
    os.LogStr(ast.serialize_type(evaluated_step1_t, ctx)); // Expected: Struct("MyNode", Some("ctx_var"))

    // Step 2 Verification: Test IndexAccess on Str (returns Byte)
    mut env_step2_test := typechecker.env_new(ctx);
    mut scope_step2_test := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    mut t_str := typechecker.make_type_str();
    typechecker.scope_insert(scope_step2_test, "my_str_var", t_str, ctx);

    mut l_step2: lexer.Lexer[ctx];
    lexer.init_lexer(&l_step2, "my_str_var[0]");
    mut p_step2: parser.Parser[ctx];
    parser.init_parser(&p_step2, &l_step2, ctx);
    mut expr_step2 := parser.parse_expression(&p_step2, 1, ctx);

    mut evaluated_step2_t := typechecker.check_expression(expr_step2, &env_step2_test, scope_step2_test, ctx);
    os.LogStr(ast.serialize_type(evaluated_step2_t, ctx)); // Expected: Byte

    // Step 1 Verification: Test env_type_is_linear
    // 1. Primitive Int
    mut t_int_test: ast.Type[ctx];
    t_int_test.tag = 0; // Int
    os.LogInt(typechecker.env_type_is_linear(t_int_test, &env, ctx)); // Expected: 0

    // 2. Index
    mut t_idx_test: ast.Type[ctx];
    t_idx_test.tag = 7; // Index
    t_idx_test.Index.struct_name = "MyNode";
    t_idx_test.Index.brand = empty[Index[str, ctx]];
    os.LogInt(typechecker.env_type_is_linear(t_idx_test, &env, ctx)); // Expected: 0

    // 3. RawPointer
    mut t_ptr_test: ast.Type[ctx];
    t_ptr_test.tag = 9; // RawPointer
    t_ptr_test.RawPointer.inner = os.ArenaAlloc(ctx);
    ctx[t_ptr_test.RawPointer.inner].tag = 0; // Int
    os.LogInt(typechecker.env_type_is_linear(t_ptr_test, &env, ctx)); // Expected: 1

    // 4. Custom POD struct Point (registered earlier)
    mut t_pod_test: ast.Type[ctx];
    t_pod_test.tag = 8; // Struct
    t_pod_test.Struct.struct_name = "Point";
    t_pod_test.Struct.brand = empty[Index[str, ctx]];
    os.LogInt(typechecker.env_type_is_linear(t_pod_test, &env, ctx)); // Expected: 0

    // 5. Custom Linear struct (containing a pointer/linear type)
    mut linear_layout: typechecker.StructLayout[ctx];
    linear_layout.brand = empty[Index[str, ctx]];
    linear_layout.fields = std.HashMapNew(ctx);
    linear_layout.fields.Insert("value", t_ptr_test);
    typechecker.env_register_struct(&env, "LinearStruct", linear_layout, ctx);

    mut t_linear_test: ast.Type[ctx];
    t_linear_test.tag = 8; // Struct
    t_linear_test.Struct.struct_name = "LinearStruct";
    t_linear_test.Struct.brand = empty[Index[str, ctx]];
    os.LogInt(typechecker.env_type_is_linear(t_linear_test, &env, ctx)); // Expected: 1

    // 6. Cyclic linked-list node
    mut cyclic_layout: typechecker.StructLayout[ctx];
    cyclic_layout.brand = empty[Index[str, ctx]];
    cyclic_layout.fields = std.HashMapNew(ctx);

    mut t_idx_cyclic: ast.Type[ctx];
    t_idx_cyclic.tag = 7; // Index
    t_idx_cyclic.Index.struct_name = "CyclicNode";
    t_idx_cyclic.Index.brand = empty[Index[str, ctx]];

    cyclic_layout.fields.Insert("next", t_idx_cyclic);
    typechecker.env_register_struct(&env, "CyclicNode", cyclic_layout, ctx);

    mut t_cyclic_test: ast.Type[ctx];
    t_cyclic_test.tag = 8; // Struct
    t_cyclic_test.Struct.struct_name = "CyclicNode";
    t_cyclic_test.Struct.brand = empty[Index[str, ctx]];
    os.LogInt(typechecker.env_type_is_linear(t_cyclic_test, &env, ctx)); // Expected: 0


    // Step 2 Verification: Test Move of Linear and POD types, and Double-Move Protection
    mut env_move_test := typechecker.env_new(ctx);
    mut scope_move_test := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    // 1. Declare and move a Linear type (Slice)
    mut t_slice_test: ast.Type[ctx];
    t_slice_test.tag = 6; // Slice
    t_slice_test.Slice.inner = os.ArenaAlloc(ctx);
    ctx[t_slice_test.Slice.inner].tag = 1; // Byte

    typechecker.scope_insert(scope_move_test, "my_linear_var", t_slice_test, ctx);
    env_move_test.variable_types.Insert("my_linear_var", t_slice_test);

    mut l_move1: lexer.Lexer[ctx];
    lexer.init_lexer(&l_move1, "move my_linear_var");
    mut p_move1: parser.Parser[ctx];
    parser.init_parser(&p_move1, &l_move1, ctx);
    mut expr_move1 := parser.parse_expression(&p_move1, 1, ctx);

    typechecker.check_expression(expr_move1, &env_move_test, scope_move_test, ctx);
    os.LogInt(env_move_test.moved_vars.Get("my_linear_var").Ok); // Expected: 1 (Added to moved_vars)

    // 2. Double-Move on Linear type
    mut l_move2: lexer.Lexer[ctx];
    lexer.init_lexer(&l_move2, "move my_linear_var");
    mut p_move2: parser.Parser[ctx];
    parser.init_parser(&p_move2, &l_move2, ctx);
    mut expr_move2 := parser.parse_expression(&p_move2, 1, ctx);

    typechecker.check_expression(expr_move2, &env_move_test, scope_move_test, ctx);

    mut has_double_move_err := 0;
    mut idx_err := 0;
    while idx_err < len(env_move_test.errors) {
        mut err := env_move_test.errors[idx_err];
        if std.str_find(err.message, "already been moved") != 0 - 1 {
            has_double_move_err = 1;
        }
        idx_err = idx_err + 1;
    }
    os.LogInt(has_double_move_err); // Expected: 1 (Double-move rejected)

    // 3. Declare and move a POD type (Int)
    mut env_move_test2 := typechecker.env_new(ctx);
    mut scope_move_test2 := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    mut t_int_move_test: ast.Type[ctx];
    t_int_test.tag = 0; // Int

    typechecker.scope_insert(scope_move_test2, "my_pod_var", t_int_move_test, ctx);
    env_move_test2.variable_types.Insert("my_pod_var", t_int_move_test);

    mut l_move3: lexer.Lexer[ctx];
    lexer.init_lexer(&l_move3, "move my_pod_var");
    mut p_move3: parser.Parser[ctx];
    parser.init_parser(&p_move3, &l_move3, ctx);
    mut expr_move3 := parser.parse_expression(&p_move3, 1, ctx);

    typechecker.check_expression(expr_move3, &env_move_test2, scope_move_test2, ctx);
    os.LogInt(env_move_test2.moved_vars.Get("my_pod_var").Ok); // Expected: 0 (POD move does not add to moved_vars)
}
