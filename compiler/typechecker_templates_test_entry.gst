import "codegen.gst" as codegen;
import "ast.gst" as ast;
import "token.gst" as token;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);

    // Verify standard templates are loaded
    if env.struct_templates.Get("Vector").Ok {
        os.LogStr("Vector template found");
    } else {
        os.LogStr("Vector template missing");
    }

    if env.struct_templates.Get("std_HashMap").Ok {
        os.LogStr("std_HashMap template found");
    } else {
        os.LogStr("std_HashMap template missing");
    }

    // Parse a custom generic structure: type Custom[T] struct { x: T }
    mut l: lexer.Lexer[ctx];
    lexer.init_lexer(&l, "type Custom[T] struct { x: T }");

    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &l, ctx);

    mut prog := parser.parse_program(&p, ctx);
    if len(p.errors) > 0 {
        os.LogStr("ParserError");
        os.Exit(1);
    }

    mut statements_vec_templates: std.Vector[ast.Statement[ctx], ctx] := ctx[prog.statements];
    if len(statements_vec_templates) > 0 {
        typechecker.env_pre_register_statement(&env, statements_vec_templates[0], ctx);
    }

    // Verify "Custom" was registered as a template and NOT a concrete struct
    if env.struct_templates.Get("Custom").Ok {
        os.LogStr("Custom registered as template");
    } else {
        os.LogStr("Custom template missing");
    }

    if env.struct_registry.Get("Custom").Ok {
        os.LogStr("Error: Custom registered in concrete registry");
    } else {
        os.LogStr("Custom absent from concrete registry");
    }

    // --- Step 2 Tests: substitute_generics and namespaced resolution ---
    env.current_prefix = "main__";
    env.imports.Insert(std.Clone(ctx, "lib"), std.Clone(ctx, "lib_module__"));

    // Register dummy namespaced struct "lib_module__MyStruct"
    mut layout: typechecker.StructLayout[ctx];
    layout.brand = empty[Index[str, ctx]];
    layout.fields = std.HashMapNew(ctx);
    typechecker.env_register_struct(&env, "lib_module__MyStruct", layout, ctx);

    // Map generic parameters: T -> lib.MyStruct (which resolves to lib_module__MyStruct), ctx -> ctx
    mut subst_map: std.HashMap[str, ast.Type[ctx], ctx] := std.HashMapNew(ctx);
    subst_map.Insert(std.Clone(ctx, "T"), typechecker.make_type_struct("lib.MyStruct", "", ctx));
    subst_map.Insert(std.Clone(ctx, "ctx"), typechecker.make_type_struct("ctx", "", ctx));

    // Test 1: Test simple primitive substitution (Int) -> should remain Int
    mut t_int := typechecker.make_type_int();
    mut res_int := typechecker.substitute_generics(&env, t_int, subst_map, ctx);
    if res_int.tag == 0 {
        os.LogStr("substitute_generics Int ok");
    }

    // Test 2: Test basic generic placeholder 'T' substitution -> should resolve to lib_module__MyStruct
    mut t_generic_placeholder := typechecker.make_type_struct("T", "", ctx);
    mut res_struct := typechecker.substitute_generics(&env, t_generic_placeholder, subst_map, ctx);
    if res_struct.tag == 8 {
        unsafe {
            os.LogStr(res_struct.Struct.struct_name); // Should print: lib_module__MyStruct
        }
    }

    // Test 3: Test pointer-to-T '*T' substitution -> should resolve to *lib_module__MyStruct
    mut t_ptr := typechecker.make_type_pointer(t_generic_placeholder, ctx);
    mut res_ptr := typechecker.substitute_generics(&env, t_ptr, subst_map, ctx);
    if res_ptr.tag == 9 {
        unsafe {
            mut inner := ctx[res_ptr.RawPointer.inner];
            if inner.tag == 8 {
                os.LogStr(std.Concat("Pointer inner: ", inner.Struct.struct_name)); // Should print: Pointer inner: lib_module__MyStruct
            }
        }
    }

    // Test 4: Test slice-of-T '[]T' substitution -> should resolve to []lib_module__MyStruct
    mut t_slice: ast.Type[ctx];
    unsafe { 
        t_slice.tag = 6;
        t_slice.Slice.inner = os.ArenaAlloc(ctx);
        ctx.Set(t_slice.Slice.inner, t_generic_placeholder);
    }
    mut res_slice := typechecker.substitute_generics(&env, t_slice, subst_map, ctx);
    if res_slice.tag == 6 {
        unsafe {
            mut inner := ctx[res_slice.Slice.inner];
            if inner.tag == 8 {
                os.LogStr(std.Concat("Slice inner: ", inner.Struct.struct_name)); // Should print: Slice inner: lib_module__MyStruct
            }
        }
    }

    // Test 5: Namespaced generic type std.Vector[lib.MyStruct, ctx] -> std_Vector[lib_module__MyStruct, ctx]
    mut t_namespaced_vector: ast.Type[ctx];
    mut args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    args.Push(typechecker.make_type_struct("lib.MyStruct", "", ctx));
    args.Push(typechecker.make_type_struct("ctx", "", ctx));
    
    unsafe {
        t_namespaced_vector.tag = 10; // Generic
        t_namespaced_vector.Generic.name = std.Clone(ctx, "std.Vector");
        t_namespaced_vector.Generic.args = os.ArenaAlloc(ctx);
        ctx.Set(t_namespaced_vector.Generic.args, args);
    }

    mut res_namespaced := typechecker.env_resolve_type(&env, t_namespaced_vector, ctx);
    if res_namespaced.tag == 10 {
        unsafe {
            os.LogStr(res_namespaced.Generic.name); // Should print: std_Vector
            mut res_args_vec: std.Vector[ast.Type[ctx], ctx] := ctx[res_namespaced.Generic.args];
            os.LogStr(res_args_vec[0].Struct.struct_name); // Should print: lib_module__MyStruct
        }
    }

    // Test 6: Verify get_monomorphized_name with resolved args -> std_Vector_lib_module__MyStruct_ctx
    mut mono_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    mono_args.Push(res_struct); // MyStruct
    mono_args.Push(typechecker.make_type_struct("ctx", "", ctx));
    
    mut mono_args_idx: Index[std.Vector[ast.Type[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(mono_args_idx, mono_args);

    mut mono_name := typechecker.get_monomorphized_name("std.Vector", mono_args_idx, ctx);
    os.LogStr(mono_name); // Should print: std_Vector_lib_module__ctx_MyNode

    // Test 7: Verify typechecker_clean_monomorphized_name alignment
    os.LogStr(typechecker.typechecker_clean_monomorphized_name("MyNode_ctx", ctx)); // Expected: MyNode
    os.LogStr(typechecker.typechecker_clean_monomorphized_name("lib_module__ctx", ctx)); // Expected: lib
    os.LogStr(typechecker.typechecker_clean_monomorphized_name("lib_module__MyNode_ctx", ctx)); // Expected: lib_module__MyNode
    os.LogStr(typechecker.typechecker_clean_monomorphized_name("std_Vector_lib_module__ctx_MyNode", ctx)); // Expected: std_Vector_lib_MyNode
    os.LogStr(typechecker.typechecker_clean_monomorphized_name("std_Vector_ctx_MyNode", ctx)); // Expected: std_Vector_MyNode

    // Test 8: Verify recursive generic type matching
    mut inner_args_int: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    inner_args_int.Push(typechecker.make_type_int());
    inner_args_int.Push(typechecker.make_type_struct("ctx", "", ctx));
    mut t_inner_int := typechecker.make_type_generic("std.Vector", inner_args_int, ctx);

    mut outer_args_int: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    outer_args_int.Push(t_inner_int);
    outer_args_int.Push(typechecker.make_type_struct("ctx", "", ctx));
    mut t_outer_int := typechecker.make_type_generic("std.Vector", outer_args_int, ctx);

    mut inner_args_bool: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    inner_args_bool.Push(typechecker.make_type_bool());
    inner_args_bool.Push(typechecker.make_type_struct("ctx", "", ctx));
    mut t_inner_bool := typechecker.make_type_generic("std.Vector", inner_args_bool, ctx);

    mut outer_args_bool: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    outer_args_bool.Push(t_inner_bool);
    outer_args_bool.Push(typechecker.make_type_struct("ctx", "", ctx));
    mut t_outer_bool := typechecker.make_type_generic("std.Vector", outer_args_bool, ctx);

    mut is_match := typechecker.types_match(t_outer_int, t_outer_bool, ctx);
    os.LogInt(is_match); // Expected: 0

    // Test 9: Verify field brand propagation
    mut t_parent := typechecker.make_type_struct("SessionNode", "my_brand", ctx);
    mut layout_lookup := env.struct_registry.Get("SessionNode");
    if layout_lookup.Ok {
        mut layout := layout_lookup.Val;
        mut field_lookup := layout.fields.Get("Next");
        if field_lookup.Ok {
            mut field_type := field_lookup.Val;
            unsafe {
                mut sub_field := typechecker.typechecker_substitute_field_brand(field_type, t_parent.Struct.brand, "n", layout, ctx);
                os.LogStr(ast.serialize_type(sub_field, ctx)); // Expected: Index("SessionNode", Some("my_brand"))
            }
        } 
    }

    // Test 10: Verify parse_types_from_suffix (Phase 2 Step 1 Fix)
    mut parsed_args := typechecker.parse_types_from_suffix(&env, "int_ctx", ctx);
    os.LogInt(len(parsed_args)); // Expected: 2
    os.LogStr(ast.serialize_type(parsed_args[0], ctx)); // Expected: Int
    os.LogStr(ast.serialize_type(parsed_args[1], ctx)); // Expected: Struct("ctx", None)

    // Test 11: Verify fallback monomorphization on env_resolve_type (Phase 2 Step 2 Fix)
    mut t_test := typechecker.make_type_struct("std_GraphNode_int_ctx", "", ctx);
    mut resolved_test := typechecker.env_resolve_type(&env, t_test, ctx);
    unsafe {
        os.LogStr(resolved_test.Struct.struct_name); // Expected: std_GraphNode_int_ctx
    }
    
    mut layout_test_lookup := env.struct_registry.Get("std_GraphNode_int_ctx");
    if layout_test_lookup.Ok {
        os.LogStr("std_GraphNode_int_ctx successfully registered!");
    } else {
        os.LogStr("std_GraphNode_int_ctx registration failed!");
    }

    // Test 12: Verify typechecker_parse_type_from_string (Step 1 Fix)
    mut parsed_t1 := typechecker.typechecker_parse_type_from_string("Index_MyNode_ctx", ctx);
    os.LogInt(parsed_t1.tag); // Expected: 7 (Index)
    unsafe {
        os.LogStr(parsed_t1.Index.struct_name); // Expected: MyNode_ctx
        if parsed_t1.Index.brand != empty[Index[str, ctx]] { 
            mut parsed_t1_brand_val: str := ctx[parsed_t1.Index.brand];
            os.LogStr(parsed_t1_brand_val); // Expected: ctx
        }
    }

    mut parsed_t2 := typechecker.typechecker_parse_type_from_string("int", ctx);
    os.LogInt(parsed_t2.tag); // Expected: 0 (Int)

    // Step 1 Verification: Test codegen_escape_string
    mut test_raw := "Hello \"World\" \\ !";
    mut test_escaped := codegen.codegen_escape_string(test_raw, ctx);
    os.LogStr(test_escaped); // Expected: Hello \"World\" \\ !

    // Step 2 Verification: Test String expression escaping
    mut expr_str_esc_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        mut expr_str_esc_ref_templates := ctx.get_ref(expr_str_esc_idx);
        expr_str_esc_ref_templates.tag = 2; // String
        expr_str_esc_ref_templates.String.val = "\"";
    }
    mut res_str_esc := codegen.codegen_generate_expression(expr_str_esc_idx, &env, ctx);
    os.LogStr(res_str_esc); // Expected: ((Slice_unsigned_char){ (unsigned char*)"\"", 1 })

    // Sub-Step 2.1 Verification: Test codegen_get_c_type_name_by_struct_name
    os.LogStr(codegen.codegen_get_c_type_name_by_struct_name("str", ctx)); // Expected: Slice_unsigned_char
    os.LogStr(codegen.codegen_get_c_type_name_by_struct_name("bool", ctx)); // Expected: unsigned char
    os.LogStr(codegen.codegen_get_c_type_name_by_struct_name("MyNode", ctx)); // Expected: MyNode

    // Parse an os.ArenaAlloc(ctx) call expression for use in the Sub-Step 2.2 test
    mut l_alloc_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_alloc_test, "os.ArenaAlloc(ctx)");
    mut p_alloc_test: parser.Parser[ctx];
    parser.init_parser(&p_alloc_test, &l_alloc_test, ctx);
    mut expr_alloc_test := parser.parse_expression(&p_alloc_test, 1, ctx);

    // Sub-Step 2.2 Verification: Test os.ArenaAlloc transpilation with "str" brand
    env.current_alloc_struct = "str";
    mut output_c_str := codegen.codegen_generate_expression(expr_alloc_test, &env, ctx);
    os.LogStr(output_c_str); // Expected: os_ArenaAlloc(&ctx, sizeof(Slice_unsigned_char))
    env.current_alloc_struct = "";

    // Sub-Step 3.1 Verification: Test codegen_erase_struct_name with namespaced brands
    mut test_brand: Index[str, ctx] := os.ArenaAlloc(ctx);
    ctx.Set(test_brand, "typechecker__ctx");
    mut erased_res := codegen.codegen_erase_struct_name("std_HashMap_str_int_typechecker__ctx", test_brand, &env, ctx);
    os.LogStr(erased_res); // Expected: std_HashMap_str_int

    // Step 1: Verification Test for codegen_is_pool_type, codegen_is_rc_type, codegen_is_graph_type
    mut t_pool_direct: ast.Type[ctx];
    unsafe {
        t_pool_direct.tag = 8; // Struct
        t_pool_direct.Struct.struct_name = "std_Pool_int_ctx";
        t_pool_direct.Struct.brand = empty[Index[str, ctx]];
    }

    mut t_pool_ptr: ast.Type[ctx];
    unsafe {
        t_pool_ptr.tag = 9; // RawPointer
        t_pool_ptr.RawPointer.inner = os.ArenaAlloc(ctx);
        ctx.Set(t_pool_ptr.RawPointer.inner, t_pool_direct);
    }

    os.LogInt(codegen.codegen_is_pool_type(t_pool_direct, &env, ctx)); // Expected: 1
    os.LogInt(codegen.codegen_is_pool_type(t_pool_ptr, &env, ctx)); // Expected: 1

    mut t_rc_direct: ast.Type[ctx];
    unsafe {
        t_rc_direct.tag = 8; // Struct
        t_rc_direct.Struct.struct_name = "std_Rc_int_ctx";
        t_rc_direct.Struct.brand = empty[Index[str, ctx]];
    }

    mut t_rc_ptr: ast.Type[ctx];
    unsafe {
        t_rc_ptr.tag = 9; // RawPointer
        t_rc_ptr.RawPointer.inner = os.ArenaAlloc(ctx);
        ctx.Set(t_rc_ptr.RawPointer.inner, t_rc_direct);
    }

    os.LogInt(codegen.codegen_is_rc_type(t_rc_direct, &env, ctx)); // Expected: 1
    os.LogInt(codegen.codegen_is_rc_type(t_rc_ptr, &env, ctx)); // Expected: 1

    mut t_graph_direct: ast.Type[ctx];
    unsafe {
        t_graph_direct.tag = 8; // Struct
        t_graph_direct.Struct.struct_name = "std_Graph_int_ctx";
        t_graph_direct.Struct.brand = empty[Index[str, ctx]];
    }

    mut t_graph_ptr: ast.Type[ctx];
    unsafe {
        t_graph_ptr.tag = 9; // RawPointer
        t_graph_ptr.RawPointer.inner = os.ArenaAlloc(ctx);
        ctx.Set(t_graph_ptr.RawPointer.inner, t_graph_direct);
    }

    os.LogInt(codegen.codegen_is_graph_type(t_graph_direct, &env, ctx)); // Expected: 1
    os.LogInt(codegen.codegen_is_graph_type(t_graph_ptr, &env, ctx)); // Expected: 1

    mut t_gena_direct: ast.Type[ctx];
    unsafe {
        t_gena_direct.tag = 8; // Struct
        t_gena_direct.Struct.struct_name = "std_GenerationalArena_int_ctx";
        t_gena_direct.Struct.brand = empty[Index[str, ctx]];
    }

    mut t_gena_ptr: ast.Type[ctx];
    unsafe {
        t_gena_ptr.tag = 9; // RawPointer
        t_gena_ptr.RawPointer.inner = os.ArenaAlloc(ctx);
        ctx.Set(t_gena_ptr.RawPointer.inner, t_gena_direct);
    }

    os.LogInt(codegen.codegen_is_generational_arena_type(t_gena_direct, &env, ctx)); // Expected: 1
    os.LogInt(codegen.codegen_is_generational_arena_type(t_gena_ptr, &env, ctx)); // Expected: 1

    // Step 2: Verification Test for std.Pool and std.Rc FFI Overrides
    mut l_pool_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_pool_test, "my_pool.Alloc(item)");
    mut p_pool_test: parser.Parser[ctx];
    parser.init_parser(&p_pool_test, &l_pool_test, ctx);
    mut expr_pool_test := parser.parse_expression(&p_pool_test, 1, ctx);
    unsafe {
        mut t_pool: ast.Type[ctx];
        t_pool.tag = 8; // Struct
        t_pool.Struct.struct_name = "std_Pool_int_ctx";
        t_pool.Struct.brand = empty[Index[str, ctx]];

        mut t_int: ast.Type[ctx];
        t_int.tag = 0; // Int

        // Setup resolved type mapping for my_pool
        mut left_expr := ctx[expr_pool_test].Call.function; // selector
        mut left_left_expr := ctx[left_expr].Selector.left; // my_pool
        mut left_left_span := parser.get_expression_span(left_left_expr, ctx);

        mut entry_p: typechecker.ResolvedTypeEntry[ctx];
        entry_p.start_offset = left_left_span.start.offset;
        entry_p.end_offset = left_left_span.end.offset;
        entry_p.val_type = t_pool;

        // Setup resolved type mapping for argument 'item'
        mut expr_pool_value: ast.Expression[ctx] := ctx[expr_pool_test];
        mut args_vec_pool_test: std.Vector[ast.Expression[ctx], ctx] := ctx[expr_pool_value.Call.arguments];
        mut arg0_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx.Set(arg0_idx, args_vec_pool_test[0]);
        mut arg0_span := parser.get_expression_span(arg0_idx, ctx);

        mut entry_i: typechecker.ResolvedTypeEntry[ctx];
        entry_i.start_offset = arg0_span.start.offset;
        entry_i.end_offset = arg0_span.end.offset;
        entry_i.val_type = t_int;

        mut found_idx := 0 - 1;
        mut p_idx := 0;
        while p_idx < len(env.resolved_types_nested) {
            if std.str_eq(env.resolved_types_nested[p_idx].prefix, env.current_prefix) {
                found_idx = p_idx;
            }
            p_idx = p_idx + 1;
        }
        if found_idx != 0 - 1 {
            mut entry_ref := &env.resolved_types_nested[found_idx];
            (*entry_ref).types.Push(entry_p);
            (*entry_ref).types.Push(entry_i);
        } else {
            mut pfx_entry: typechecker.PrefixMapEntry[ctx];
            pfx_entry.prefix = env.current_prefix;
            pfx_entry.types = std.VectorNew(ctx);
            pfx_entry.types.Push(entry_p);
            pfx_entry.types.Push(entry_i);
            env.resolved_types_nested.Push(pfx_entry);
        }

        mut output_c := codegen.codegen_generate_expression(expr_pool_test, &env, ctx);
        os.LogStr(output_c); // Expected: std_PoolAlloc(&my_pool, item)
    }

    mut l_rc_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_rc_test, "rc_ptr.Get()");
    mut p_rc_test: parser.Parser[ctx];
    parser.init_parser(&p_rc_test, &l_rc_test, ctx);
    mut expr_rc_test := parser.parse_expression(&p_rc_test, 1, ctx);
    unsafe {
        mut t_rc_inner: ast.Type[ctx];
        t_rc_inner.tag = 8; // Struct
        t_rc_inner.Struct.struct_name = "std_Rc_int_ctx";
        t_rc_inner.Struct.brand = empty[Index[str, ctx]];

        mut t_rc_ptr: ast.Type[ctx];
        t_rc_ptr.tag = 9; // RawPointer
        t_rc_ptr.RawPointer.inner = os.ArenaAlloc(ctx);
        ctx.Set(t_rc_ptr.RawPointer.inner, t_rc_inner);

        // Setup resolved type mapping for rc_ptr
        mut left_expr := ctx[expr_rc_test].Call.function; // selector
        mut left_left_expr := ctx[left_expr].Selector.left; // rc_ptr
        mut left_left_span := parser.get_expression_span(left_left_expr, ctx);

        mut entry_rc: typechecker.ResolvedTypeEntry[ctx];
        entry_rc.start_offset = left_left_span.start.offset;
        entry_rc.end_offset = left_left_span.end.offset;
        entry_rc.val_type = t_rc_ptr;

        mut found_idx := 0 - 1;
        mut p_idx := 0;
        while p_idx < len(env.resolved_types_nested) {
            if std.str_eq(env.resolved_types_nested[p_idx].prefix, env.current_prefix) {
                found_idx = p_idx;
            }
            p_idx = p_idx + 1;
        }
        if found_idx != 0 - 1 {
            mut entry_ref := &env.resolved_types_nested[found_idx];
            (*entry_ref).types.Push(entry_rc);
        } else {
            mut pfx_entry: typechecker.PrefixMapEntry[ctx];
            pfx_entry.prefix = env.current_prefix;
            pfx_entry.types = std.VectorNew(ctx);
            pfx_entry.types.Push(entry_rc);
            env.resolved_types_nested.Push(pfx_entry);
        }

        mut output_c := codegen.codegen_generate_expression(expr_rc_test, &env, ctx);
        os.LogStr(output_c); // Expected: std_RcGet(rc_ptr)
    }
}

