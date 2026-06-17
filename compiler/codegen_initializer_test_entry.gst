import "ast.gst" as ast;
import "token.gst" as token;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;
import "codegen.gst" as codegen;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);
    
    mut c: codegen.Codegen[ctx];
    codegen.init_codegen(&c, &env, ctx);

    // Assert empty state for Step 1
    if std.str_eq(c.current_alloc_struct, "") {
        os.LogStr("current_alloc_struct is initialized empty");
    }
    os.LogInt(len(c.current_params)); // Expected: 0

    // Test Step 1: Guard Statement Transpilation Routing
    mut l_guard_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_guard_test, "guard mut x := map.Get(42) else { return; }");
    mut p_guard_test: parser.Parser[ctx];
    parser.init_parser(&p_guard_test, &l_guard_test, ctx);
    mut prog_guard_test := parser.parse_program(&p_guard_test, ctx);
    unsafe {
        mut statements_vec := &ctx[prog_guard_test.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut guard_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[guard_stmt_idx] = (*statements_vec)[0];
        
        // Step 2: Pre-populate variable_types and resolved_types to test type resolution
        mut value_expr := ctx[guard_stmt_idx].Guard.value;
        mut value_span := parser.get_expression_span(value_expr, ctx);

        mut wrapper_type: ast.Type[ctx];
        wrapper_type.tag = 8; // Struct
        wrapper_type.Struct.struct_name = "LookupResult_os_Dir_ctx";
        wrapper_type.Struct.brand = empty[Index[str, ctx]];

        mut entry: typechecker.ResolvedTypeEntry[ctx];
        entry.start_offset = value_span.start.offset;
        entry.end_offset = value_span.end.offset;
        entry.val_type = wrapper_type;

        mut pfx_entry: typechecker.PrefixMapEntry[ctx];
        pfx_entry.prefix = "";
        pfx_entry.types = std.VectorNew(ctx); 
        pfx_entry.types.Push(entry);

        env.resolved_types_nested.Push(pfx_entry);

        mut payload_type: ast.Type[ctx];
        payload_type.tag = 8; // Struct
        payload_type.Struct.struct_name = "os_Dir_ctx";
        payload_type.Struct.brand = empty[Index[str, ctx]];

        env.variable_types.Insert("x", payload_type);

        mut guard_c := codegen.codegen_generate_statement(guard_stmt_idx, &env, ctx);
        os.LogStr(guard_c); // Expected: if (!_guard_res_x_1_1.Ok) { 
                            //              return; 
                            //          }
    }

    // Test Step 1 Skip List
    if codegen.codegen_should_skip_fwd_decl("std.Clone") == 1 {
        os.LogStr("std.Clone correctly flagged as intrinsic");
    } else {
        os.LogStr("std.Clone NOT flagged as intrinsic");
    }

    if codegen.codegen_should_skip_fwd_decl("my_user_func") == 0 {
        os.LogStr("my_user_func correctly not flagged as intrinsic");
    } else { 
        os.LogStr("my_user_func incorrectly flagged as intrinsic");
    }

    // Test Step 2 Forward Declaration Generation
    mut sig_test: typechecker.FunctionSignature[ctx];
    sig_test.param_names = std.VectorNew(ctx);
    sig_test.params = std.VectorNew(ctx);

    sig_test.return_type.tag = 2; // Bool -> unsigned char

    // Param 1: x: int
    sig_test.param_names.Push("x");
    mut t_param_int: ast.Type[ctx];
    t_param_int.tag = 0;
    sig_test.params.Push(t_param_int);

    // Param 2: arena_ptr: &Arena
    sig_test.param_names.Push("arena_ptr");
    mut t_param_arena_ptr: ast.Type[ctx];
    t_param_arena_ptr.tag = 9; // RawPointer
    t_param_arena_ptr.RawPointer.inner = os.ArenaAlloc(ctx);
    ctx[t_param_arena_ptr.RawPointer.inner].tag = 4; // Arena
    sig_test.params.Push(t_param_arena_ptr);

    // Param 3: arena_val: Arena
    sig_test.param_names.Push("arena_val");
    mut t_param_arena: ast.Type[ctx];
    t_param_arena.tag = 4; // Arena
    sig_test.params.Push(t_param_arena);

    mut fwd_decl := codegen.codegen_gen_function_fwd_decl("lib.my_awesome_func", sig_test, &env, ctx);
    os.LogStr(fwd_decl);

    // Test Step 2: Statement Traversal Tracking
    // Parse a function declaration with parameters
    mut l_func_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_func_test, "func my_test_func(param_a: int, param_b: bool) {}");
    mut p_func_test: parser.Parser[ctx];
    parser.init_parser(&p_func_test, &l_func_test, ctx);
    mut prog_func_test := parser.parse_program(&p_func_test, ctx);
    unsafe {
        mut statements_vec := &ctx[prog_func_test.statements] as *std.Vector[ast.Statement[ctx], ctx];
        typechecker.env_pre_register_statement(&env, (*statements_vec)[0], ctx);
        
        mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[stmt_idx] = (*statements_vec)[0];
        
        // Execute statement generation
        mut _discard := codegen.codegen_generate_statement(stmt_idx, &env, ctx);
        
        // Verify that the parameters were populated during the traversal
        os.LogInt(len(env.current_params)); // Expected: 2 (param_a and param_b)
        os.LogStr(env.current_params[0]); // Expected: param_a
        os.LogStr(env.current_params[1]); // Expected: param_b
    }

    // Test Step 3: os.ArenaAlloc Transpilation
    // Parse an os.ArenaAlloc(ctx) call expression
    mut l_alloc_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_alloc_test, "os.ArenaAlloc(ctx)");
    mut p_alloc_test: parser.Parser[ctx];
    parser.init_parser(&p_alloc_test, &l_alloc_test, ctx);
    mut expr_alloc_test := parser.parse_expression(&p_alloc_test, 1, ctx);
    unsafe {
        env.current_alloc_struct = "MyTestStruct";
        mut output_c := codegen.codegen_generate_expression(expr_alloc_test, &env, ctx);
        os.LogStr(output_c); // Expected: os_ArenaAlloc(&ctx, sizeof(MyTestStruct))
        env.current_alloc_struct = "";
    }

    // Test Step 4: Refit ctx Pointer-vs-Value Resolution
    unsafe {
        // Case A: ctx is a parameter (should transpile to "ctx" without "&")
        env.current_params.Clear();
        env.current_params.Push("ctx");
        
        mut output_c_param := codegen.codegen_generate_expression(expr_alloc_test, &env, ctx);
        os.LogStr(output_c_param); // Expected: os_ArenaAlloc(ctx, sizeof(SessionNode))
        
        // Case B: ctx is NOT a parameter, but a global/local variable of type Arena (should transpile to "&ctx")
        env.current_params.Clear();
        mut t_arena: ast.Type[ctx];
        t_arena.tag = 4; // Arena
        env.variable_types.Insert("ctx", t_arena);
        
        mut output_c_val := codegen.codegen_generate_expression(expr_alloc_test, &env, ctx);
        os.LogStr(output_c_val); // Expected: os_ArenaAlloc(&ctx, sizeof(SessionNode))
    }

    // 1. Test primitive types
    mut t_int: ast.Type[ctx];
    t_int.tag = 0; // Int
    mut init_int := codegen.codegen_gen_type_aware_initializer(t_int, &env, ctx);
    os.LogStr(init_int); // Expected: 0

    // 2. Test Index type
    mut t_index: ast.Type[ctx];
    t_index.tag = 7; // Index
    t_index.Index.struct_name = "Node";
    t_index.Index.brand = empty[Index[str, ctx]];
    mut init_index := codegen.codegen_gen_type_aware_initializer(t_index, &env, ctx);
    os.LogStr(init_index); // Expected: 0xFFFFFFFF

    // 3. Test RawPointer type
    mut t_ptr: ast.Type[ctx];
    t_ptr.tag = 9; // RawPointer
    mut inner_idx: Index[ast.Type[ctx], ctx] := os.ArenaAlloc(ctx);
    t_ptr.RawPointer.inner = inner_idx;
    ctx[t_ptr.RawPointer.inner].tag = 0; // Int
    mut init_ptr := codegen.codegen_gen_type_aware_initializer(t_ptr, &env, ctx);
    os.LogStr(init_ptr); // Expected: NULL

    // 4. Register and test a custom struct Point { x: int, y: int }
    mut l: lexer.Lexer[ctx];
    lexer.init_lexer(&l, "type Point struct { y: int, x: int }");

    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &l, ctx);

    mut prog := parser.parse_program(&p, ctx);
    unsafe {
        mut statements_vec := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
        typechecker.env_pre_register_statement(&env, (*statements_vec)[0], ctx);
    }

    mut t_point: ast.Type[ctx];
    t_point.tag = 8; // Struct
    t_point.Struct.struct_name = "Point";
    t_point.Struct.brand = empty[Index[str, ctx]];

    mut init_point := codegen.codegen_gen_type_aware_initializer(t_point, &env, ctx);
    os.LogStr(init_point); // Expected: ((Point){ .x = 0, .y = 0 }) (alphabetically sorted!)

    // 5. Test codegen_has_boolean_fields
    // Point has no boolean fields (x: int, y: int)
    mut has_bool_point := codegen.codegen_has_boolean_fields(t_point, &env, ctx);
    os.LogInt(has_bool_point); // Expected: 0

    // Register a custom struct Node { val: int, active: bool }
    mut l2: lexer.Lexer[ctx];
    lexer.init_lexer(&l2, "type Node struct { val: int, active: bool }");

    mut p2: parser.Parser[ctx];
    parser.init_parser(&p2, &l2, ctx);

    mut prog2 := parser.parse_program(&p2, ctx);
    unsafe {
        mut statements_vec := &ctx[prog2.statements] as *std.Vector[ast.Statement[ctx], ctx];
        typechecker.env_pre_register_statement(&env, (*statements_vec)[0], ctx);
    }

    mut t_node: ast.Type[ctx];
    t_node.tag = 8; // Struct
    t_node.Struct.struct_name = "Node";
    t_node.Struct.brand = empty[Index[str, ctx]];

    mut has_bool_node := codegen.codegen_has_boolean_fields(t_node, &env, ctx);
    os.LogInt(has_bool_node); // Expected: 1

    // Register a custom struct ParentNode { child: Node, id: int } (nested bool test)
    mut l3: lexer.Lexer[ctx];
    lexer.init_lexer(&l3, "type ParentNode struct { child: Node, id: int }");

    mut p3: parser.Parser[ctx];
    parser.init_parser(&p3, &l3, ctx);

    mut prog3 := parser.parse_program(&p3, ctx);
    unsafe {
        mut statements_vec := &ctx[prog3.statements] as *std.Vector[ast.Statement[ctx], ctx];
        typechecker.env_pre_register_statement(&env, (*statements_vec)[0], ctx);
    }

    mut t_parent: ast.Type[ctx];
    t_parent.tag = 8; // Struct
    t_parent.Struct.struct_name = "ParentNode";
    t_parent.Struct.brand = empty[Index[str, ctx]];

    mut has_bool_parent := codegen.codegen_has_boolean_fields(t_parent, &env, ctx);
    os.LogInt(has_bool_parent); // Expected: 1

    // 6. Test codegen_gen_is_valid_helper
    mut lookup_node := env.struct_registry.Get("Node");
    if lookup_node.Ok {
        mut is_valid_str := codegen.codegen_gen_is_valid_helper("Node", lookup_node.Val, &env, ctx);
        os.LogStr(is_valid_str);
    }

    // 7. Test codegen_generate
    mut test_programs: std.Vector[ast.Program[ctx], ctx] := std.VectorNew(ctx);
    test_programs.Push(prog2);
    mut test_prefixes: std.Vector[str, ctx] := std.VectorNew(ctx);
    test_prefixes.Push("");
    mut full_c := codegen.codegen_generate(test_programs, test_prefixes, &env, ctx);
    os.LogStr(full_c);

    // 8. Test Topological Sorting in Codegen
    mut l4: lexer.Lexer[ctx];
    lexer.init_lexer(&l4, "type Outer struct { inner: Inner } type Inner struct { val: int }");

    mut p4: parser.Parser[ctx];
    parser.init_parser(&p4, &l4, ctx);

    mut prog4 := parser.parse_program(&p4, ctx);
    unsafe {
        mut statements_vec := &ctx[prog4.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut i := 0;
        while i < len(*statements_vec) {
            typechecker.env_pre_register_statement(&env, (*statements_vec)[i], ctx);
            i = i + 1;
        }
    }

    mut sorted_structs := codegen.codegen_get_topologically_sorted_structs(&env, ctx);
    
    // Find positions of "Outer" and "Inner" in the sorted structs
    mut topo_outer_idx := 0 - 1;
    mut topo_inner_idx := 0 - 1;
    mut topo_s_idx := 0;
    while topo_s_idx < len(sorted_structs) {
        mut name := sorted_structs[topo_s_idx];
        if std.str_eq(name, "Outer") {
            topo_outer_idx = topo_s_idx;
        }
        if std.str_eq(name, "Inner") {
            topo_inner_idx = topo_s_idx;
        }
        topo_s_idx = topo_s_idx + 1;
    }

    if topo_inner_idx != 0 - 1 && topo_outer_idx != 0 - 1 {
        if topo_inner_idx < topo_outer_idx {
            os.LogStr("Topological Sort OK: Inner precedes Outer");
        } else {
            os.LogStr("Topological Sort FAIL: Outer precedes Inner");
        }
    } else { 
        os.LogStr("Topological Sort FAIL: Missing structs");
    }

    // 9. Test Topological Sorting of ADT Variants
    mut l5: lexer.Lexer[ctx];
    lexer.init_lexer(&l5, "type MyEnum enum { VariantA { val: int }, VariantB }");

    mut p5: parser.Parser[ctx];
    parser.init_parser(&p5, &l5, ctx);

    mut prog5 := parser.parse_program(&p5, ctx);
    unsafe {
        mut statements_vec := &ctx[prog5.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut i := 0;
        while i < len(*statements_vec) {
            typechecker.env_pre_register_statement(&env, (*statements_vec)[i], ctx);
            i = i + 1;
        }
    }

    mut sorted_structs2 := codegen.codegen_get_topologically_sorted_structs(&env, ctx);
    
    // Find positions of "MyEnum" and "MyEnum_VariantA" in the sorted structs
    mut enum_idx := 0 - 1;
    mut variant_idx := 0 - 1;
    mut s_idx2 := 0;
    while s_idx2 < len(sorted_structs2) {
        mut name := sorted_structs2[s_idx2];
        if std.str_eq(name, "MyEnum") {
            enum_idx = s_idx2;
        }
        if std.str_eq(name, "MyEnum_VariantA") {
            variant_idx = s_idx2;
        }
        s_idx2 = s_idx2 + 1;
    }

    if variant_idx != 0 - 1 && enum_idx != 0 - 1 {
        if variant_idx < enum_idx {
            os.LogStr("Topological Sort ADT OK: Variant precedes Enum");
        } else {
            os.LogStr("Topological Sort ADT FAIL: Enum precedes Variant");
        }
    } else {
        os.LogStr("Topological Sort ADT FAIL: Missing structs");
    }
}
