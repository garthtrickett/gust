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

    unsafe {
        mut statements_vec := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
        if len(*statements_vec) > 0 {
            typechecker.env_pre_register_statement(&env, (*statements_vec)[0], ctx);
        }
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
        os.LogStr(res_struct.Struct.struct_name); // Should print: lib_module__MyStruct
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
    t_slice.tag = 6;
    t_slice.Slice.inner = os.ArenaAlloc(ctx);
    unsafe {
        ctx[t_slice.Slice.inner] = t_generic_placeholder;
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
    t_namespaced_vector.tag = 10; // Generic
    t_namespaced_vector.Generic.name = std.Clone(ctx, "std.Vector");
    
    mut args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    args.Push(typechecker.make_type_struct("lib.MyStruct", "", ctx));
    args.Push(typechecker.make_type_struct("ctx", "", ctx));
    
    t_namespaced_vector.Generic.args = os.ArenaAlloc(ctx);
    unsafe {
        mut args_ptr := &ctx[t_namespaced_vector.Generic.args] as *std.Vector[ast.Type[ctx], ctx];
        *args_ptr = args;
    }

    mut res_namespaced := typechecker.env_resolve_type(&env, t_namespaced_vector, ctx);
    if res_namespaced.tag == 10 {
        os.LogStr(res_namespaced.Generic.name); // Should print: std_Vector
        unsafe {
            mut res_args := &ctx[res_namespaced.Generic.args] as *std.Vector[ast.Type[ctx], ctx];
            os.LogStr((*res_args)[0].Struct.struct_name); // Should print: lib_module__MyStruct
        }
    }

    // Test 6: Verify get_monomorphized_name with resolved args -> std_Vector_lib_module__MyStruct_ctx
    mut mono_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    mono_args.Push(res_struct); // MyStruct
    mono_args.Push(typechecker.make_type_struct("ctx", "", ctx));
    
    mut mono_args_idx: Index[std.Vector[ast.Type[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        mut mono_args_ptr := &ctx[mono_args_idx] as *std.Vector[ast.Type[ctx], ctx];
        *mono_args_ptr = mono_args;
    }

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
            mut sub_field := typechecker.typechecker_substitute_field_brand(field_type, t_parent.Struct.brand, "n", layout, ctx);
            os.LogStr(ast.serialize_type(sub_field, ctx)); // Expected: Index("SessionNode", Some("my_brand"))
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
    os.LogStr(resolved_test.Struct.struct_name); // Expected: std_GraphNode_int_ctx
    
    mut layout_test_lookup := env.struct_registry.Get("std_GraphNode_int_ctx");
    if layout_test_lookup.Ok {
        os.LogStr("std_GraphNode_int_ctx successfully registered!");
    } else {
        os.LogStr("std_GraphNode_int_ctx registration failed!");
    }

    // Test 12: Verify typechecker_parse_type_from_string (Step 1 Fix)
    mut parsed_t1 := typechecker.typechecker_parse_type_from_string("Index_MyNode_ctx", ctx);
    os.LogInt(parsed_t1.tag); // Expected: 7 (Index)
    os.LogStr(parsed_t1.Index.struct_name); // Expected: MyNode_ctx
    if parsed_t1.Index.brand != empty[Index[str, ctx]] { 
        unsafe {
            mut b_ptr := &ctx[parsed_t1.Index.brand] as *str;
            os.LogStr(*b_ptr); // Expected: ctx
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
    ctx[expr_str_esc_idx].tag = 2; // String
    ctx[expr_str_esc_idx].String.val = "\"";
    mut res_str_esc := codegen.codegen_generate_expression(expr_str_esc_idx, &env, ctx);
    os.LogStr(res_str_esc); // Expected: ((Slice_unsigned_char){ (unsigned char*)"\"", 1 })

    // Sub-Step 2.1 Verification: Test codegen_get_c_type_name_by_struct_name
    os.LogStr(codegen.codegen_get_c_type_name_by_struct_name("str", ctx)); // Expected: Slice_unsigned_char
    os.LogStr(codegen.codegen_get_c_type_name_by_struct_name("bool", ctx)); // Expected: unsigned char
    os.LogStr(codegen.codegen_get_c_type_name_by_struct_name("MyNode", ctx)); // Expected: MyNode

    // Sub-Step 2.2 Verification: Test os.ArenaAlloc transpilation with "str" brand
    env.current_alloc_struct = "str";
    mut output_c_str := codegen.codegen_generate_expression(expr_alloc_test, &env, ctx);
    os.LogStr(output_c_str); // Expected: os_ArenaAlloc(&ctx, sizeof(Slice_unsigned_char))
    env.current_alloc_struct = "";

}
