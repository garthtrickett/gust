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
}
