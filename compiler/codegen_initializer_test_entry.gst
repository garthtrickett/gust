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
        os.LogStr(guard_c); // Expected:
                            //     LookupResult_os_Dir_ctx _guard_res_x_1_1 = {0};
                            //     _guard_res_x_1_1 = map_Get(42);
                            //     if (!_guard_res_x_1_1.Ok) {
                            //         return;
                            //     }
                            //     os_Dir_ctx x = _guard_res_x_1_1.Val;
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

        // Direct test for codegen_is_arena_val fallback behavior (Step 1)
        env.current_params.Clear();
        env.variable_types.Remove("ctx"); // Simulate empty/clashing symbol table
        if codegen.codegen_is_arena_val("ctx", &env, ctx) == 1 {
            os.LogStr("is_arena_val direct fallback OK: local ctx is value");
        }
        
        env.current_params.Push("ctx");
        if codegen.codegen_is_arena_val("ctx", &env, ctx) == 0 {
            os.LogStr("is_arena_val direct fallback OK: parameter ctx is not value");
        }

        // Direct test for codegen_is_arena_ptr fallback behavior (Step 2)
        env.current_params.Clear();
        env.variable_types.Remove("ctx"); // Simulate empty/clashing symbol table
        if codegen.codegen_is_arena_ptr("ctx", &env, ctx) == 0 {
            os.LogStr("is_arena_ptr direct fallback OK: local ctx is not ptr");
        }
        
        env.current_params.Push("ctx");
        if codegen.codegen_is_arena_ptr("ctx", &env, ctx) == 1 {
            os.LogStr("is_arena_ptr direct fallback OK: parameter ctx is not value");
        }

        // Direct test for general call argument generation (Step 1)
        mut l_general_call: lexer.Lexer[ctx];
        lexer.init_lexer(&l_general_call, "my_user_func(ctx)");
        mut p_general_call: parser.Parser[ctx];
        parser.init_parser(&p_general_call, &l_general_call, ctx);
        mut expr_general_call := parser.parse_expression(&p_general_call, 1, ctx);
        
        // Case A: ctx is in current_params (function parameter) -> should generate my_user_func(ctx)
        env.current_params.Clear();
        env.current_params.Push("ctx");
        mut out_general_param := codegen.codegen_generate_expression(expr_general_call, &env, ctx);
        os.LogStr(out_general_param);
        
        // Case B: ctx is NOT in current_params (local value) -> should generate my_user_func(&ctx)
        env.current_params.Clear();
        mut out_general_val := codegen.codegen_generate_expression(expr_general_call, &env, ctx);
        os.LogStr(out_general_val);

        // Direct test for FFI Override os.ReadFile (Step 2)
        mut l_readfile: lexer.Lexer[ctx];
        lexer.init_lexer(&l_readfile, "os.ReadFile(ctx, \"path.txt\")");
        mut p_readfile: parser.Parser[ctx];
        parser.init_parser(&p_readfile, &l_readfile, ctx);
        mut expr_readfile := parser.parse_expression(&p_readfile, 1, ctx);

        // Case A: ctx is in current_params (parameter) -> should generate os_ReadFile(ctx, "path.txt")
        env.current_params.Clear();
        env.current_params.Push("ctx");
        mut out_readfile_param := codegen.codegen_generate_expression(expr_readfile, &env, ctx);
        os.LogStr(out_readfile_param);

        // Case B: ctx is NOT in current_params (local value) -> should generate os_ReadFile(&ctx, "path.txt")
        env.current_params.Clear();
        mut out_readfile_val := codegen.codegen_generate_expression(expr_readfile, &env, ctx);
        os.LogStr(out_readfile_val);

        // Direct test for FFI Override std.Clone (Step 2)
        mut l_clone: lexer.Lexer[ctx];
        lexer.init_lexer(&l_clone, "std.Clone(ctx, node)");
        mut p_clone: parser.Parser[ctx];
        parser.init_parser(&p_clone, &l_clone, ctx);
        mut expr_clone := parser.parse_expression(&p_clone, 1, ctx);

        // Pre-register 'node' of type Index[SessionNode, current_ctx] so Clone finds its brand
        mut t_node_idx: ast.Type[ctx];
        t_node_idx.tag = 7; // Index
        t_node_idx.Index.struct_name = "SessionNode";
        t_node_idx.Index.brand = empty[Index[str, ctx]];
        unsafe {
            t_node_idx.Index.brand = os.ArenaAlloc(ctx) as Index[str, ctx];
            mut brand_ptr := &ctx[t_node_idx.Index.brand] as *str;
            *brand_ptr = "current_ctx";
        }
        // Insert into resolved types for the expression 'node'
        mut node_expr_idx := ctx[expr_clone].Call.arguments; // Vector[Expression]
        unsafe {
            mut args_vec := &ctx[node_expr_idx] as *std.Vector[ast.Expression[ctx], ctx];
            mut arg1_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[arg1_idx] = (*args_vec)[1];
            mut span1 := parser.get_expression_span(arg1_idx, ctx);
            
            mut entry_node: typechecker.ResolvedTypeEntry[ctx];
            entry_node.start_offset = span1.start.offset;
            entry_node.end_offset = span1.end.offset;
            entry_node.val_type = t_node_idx;

            mut found_idx := 0 - 1;
            mut p_idx := 0;
            while p_idx < len(env.resolved_types_nested) {
                if std.str_eq(env.resolved_types_nested[p_idx].prefix, "") {
                    found_idx = p_idx;
                }
                p_idx = p_idx + 1;
            }
            if found_idx != 0 - 1 {
                mut entry_ref := &env.resolved_types_nested[found_idx];
                (*entry_ref).types.Push(entry_node);
            }
        }

        // Case A: ctx is in current_params (parameter) -> should generate os_ArenaAlloc(ctx, sizeof(SessionNode))
        env.current_params.Clear();
        env.current_params.Push("ctx");
        mut out_clone_param := codegen.codegen_generate_expression(expr_clone, &env, ctx);
        os.LogStr(out_clone_param);

        // Case B: ctx is NOT in current_params (local value) -> should generate os_ArenaAlloc(&ctx, sizeof(SessionNode))
        env.current_params.Clear();
        mut out_clone_val := codegen.codegen_generate_expression(expr_clone, &env, ctx);
        os.LogStr(out_clone_val);

        // Direct test for FFI Override std.Clone with Str argument (Step 2 Str deep-cloning)
        mut l_clone_str: lexer.Lexer[ctx];
        lexer.init_lexer(&l_clone_str, "std.Clone(ctx, my_str_val)");
        mut p_clone_str: parser.Parser[ctx];
        parser.init_parser(&p_clone_str, &l_clone_str, ctx);
        mut expr_clone_str := parser.parse_expression(&p_clone_str, 1, ctx);

        // Pre-register 'my_str_val' of type Str (5) so Clone is treated as Str deep clone
        mut t_str_var: ast.Type[ctx];
        t_str_var.tag = 5; // Str
        
        mut span_str_var: token.Span;
        unsafe {
            mut args_vec := &ctx[ctx[expr_clone_str].Call.arguments] as *std.Vector[ast.Expression[ctx], ctx];
            mut arg1_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[arg1_idx] = (*args_vec)[1];
            span_str_var = parser.get_expression_span(arg1_idx, ctx);
            
            mut entry_str: typechecker.ResolvedTypeEntry[ctx];
            entry_str.start_offset = span_str_var.start.offset;
            entry_str.end_offset = span_str_var.end.offset;
            entry_str.val_type = t_str_var;

            mut found_idx := 0 - 1;
            mut p_idx := 0;
            while p_idx < len(env.resolved_types_nested) {
                if std.str_eq(env.resolved_types_nested[p_idx].prefix, "") {
                    found_idx = p_idx;
                }
                p_idx = p_idx + 1;
            }
            if found_idx != 0 - 1 {
                mut entry_ref := &env.resolved_types_nested[found_idx];
                (*entry_ref).types.Push(entry_str);
            }
        }

        // Case A: ctx is in current_params (parameter) -> should generate std_Clone_str(ctx, my_str_val)
        env.current_params.Clear();
        env.current_params.Push("ctx");
        mut out_clone_str_param := codegen.codegen_generate_expression(expr_clone_str, &env, ctx);
        os.LogStr(out_clone_str_param);

        // Case B: ctx is NOT in current_params (local value) -> should generate std_Clone_str(&ctx, my_str_val)
        env.current_params.Clear();
        mut out_clone_str_val := codegen.codegen_generate_expression(expr_clone_str, &env, ctx);
        os.LogStr(out_clone_str_val);

        // Direct test for Branded Collection Initializer std.VectorNew (Step 1)
        mut l_vecnew: lexer.Lexer[ctx];
        lexer.init_lexer(&l_vecnew, "std.VectorNew(ctx)");
        mut p_vecnew: parser.Parser[ctx];
        parser.init_parser(&p_vecnew, &l_vecnew, ctx);
        mut expr_vecnew := parser.parse_expression(&p_vecnew, 1, ctx);

        // Setup current_alloc_struct to simulate type-aware instantiation
        env.current_alloc_struct = "std_Vector_int_ctx";

        // Case A: ctx is in current_params (parameter) -> .arena = ctx
        env.current_params.Clear();
        env.current_params.Push("ctx");
        mut out_vecnew_param := codegen.codegen_generate_expression(expr_vecnew, &env, ctx);
        os.LogStr(out_vecnew_param);

        // Case B: ctx is NOT in current_params (local value) -> .arena = &ctx
        env.current_params.Clear();
        mut out_vecnew_val := codegen.codegen_generate_expression(expr_vecnew, &env, ctx);
        os.LogStr(out_vecnew_val);
        env.current_alloc_struct = "";

        // Direct test for Branded Collection Initializer std.HashMapNew (Step 1)
        mut l_mapnew: lexer.Lexer[ctx];
        lexer.init_lexer(&l_mapnew, "std.HashMapNew(ctx)");
        mut p_mapnew: parser.Parser[ctx];
        parser.init_parser(&p_mapnew, &l_mapnew, ctx);
        mut expr_mapnew := parser.parse_expression(&p_mapnew, 1, ctx);

        // Setup current_alloc_struct to simulate type-aware instantiation
        env.current_alloc_struct = "std_HashMap_int_int_ctx";

        // Case A: ctx is in current_params (parameter) -> .arena = ctx
        env.current_params.Clear();
        env.current_params.Push("ctx");
        mut out_mapnew_param := codegen.codegen_generate_expression(expr_mapnew, &env, ctx);
        os.LogStr(out_mapnew_param);

        // Case B: ctx is NOT in current_params (local value) -> .arena = &ctx
        env.current_params.Clear();
        mut out_mapnew_val := codegen.codegen_generate_expression(expr_mapnew, &env, ctx);
        os.LogStr(out_mapnew_val);
        env.current_alloc_struct = "";

        // Direct test for FFI Block Helper os.Args (Step 2)
        mut l_args: lexer.Lexer[ctx];
        lexer.init_lexer(&l_args, "os.Args(ctx)");
        mut p_args: parser.Parser[ctx];
        parser.init_parser(&p_args, &l_args, ctx);
        mut expr_args := parser.parse_expression(&p_args, 1, ctx);

        // Case A: ctx is in current_params (parameter) -> os_Arena* _ctx = ctx
        env.current_params.Clear();
        env.current_params.Push("ctx");
        mut out_args_param := codegen.codegen_generate_expression(expr_args, &env, ctx);
        os.LogStr(out_args_param);

        // Case B: ctx is NOT in current_params (local value) -> os_Arena* _ctx = &ctx
        env.current_params.Clear();
        mut out_args_val := codegen.codegen_generate_expression(expr_args, &env, ctx);
        os.LogStr(out_args_val);

        // Test Step 4: Cast-Aware Allocation Size Propagation (Step 4 Fix)
        mut l_cast_alloc_test: lexer.Lexer[ctx];
        lexer.init_lexer(&l_cast_alloc_test, "os.ArenaAlloc(ctx) as Index[ListNode, ctx]");
        mut p_cast_alloc_test: parser.Parser[ctx];
        parser.init_parser(&p_cast_alloc_test, &l_cast_alloc_test, ctx);
        mut expr_cast_alloc_test := parser.parse_expression(&p_cast_alloc_test, 1, ctx);
        
        // Register ListNode in struct registry
        mut listnode_layout: typechecker.StructLayout[ctx];
        listnode_layout.brand = empty[Index[str, ctx]];
        listnode_layout.fields = std.HashMapNew(ctx);
        typechecker.env_register_struct(&env, "ListNode", listnode_layout, ctx);
        
        // Setup resolved types to simulate proper compilation type mapping
        mut t_listnode_idx: ast.Type[ctx];
        t_listnode_idx.tag = 7; // Index
        t_listnode_idx.Index.struct_name = "ListNode_ctx";
        t_listnode_idx.Index.brand = empty[Index[str, ctx]];
        unsafe {
            t_listnode_idx.Index.brand = os.ArenaAlloc(ctx) as Index[str, ctx];
            mut brand_ptr := &ctx[t_listnode_idx.Index.brand] as *str;
            *brand_ptr = "ctx";
        }
        
        mut cast_alloc_span := parser.get_expression_span(expr_cast_alloc_test, ctx);
        mut entry_cast_alloc: typechecker.ResolvedTypeEntry[ctx];
        entry_cast_alloc.start_offset = cast_alloc_span.start.offset;
        entry_cast_alloc.end_offset = cast_alloc_span.end.offset;
        entry_cast_alloc.val_type = t_listnode_idx;
        
        mut found_cast_idx := 0 - 1;
        mut idx_cast := 0;
        while idx_cast < len(env.resolved_types_nested) {
            if std.str_eq(env.resolved_types_nested[idx_cast].prefix, "") == 1 {
                found_cast_idx = idx_cast;
            }
            idx_cast = idx_cast + 1;
        }
        if found_cast_idx != 0 - 1 {
            mut entry_ref_cast := &env.resolved_types_nested[found_cast_idx];
            (*entry_ref_cast).types.Push(entry_cast_alloc);
        } else {
            mut pfx_entry_cast: typechecker.PrefixMapEntry[ctx];
            pfx_entry_cast.prefix = "";
            pfx_entry_cast.types = std.VectorNew(ctx);
            pfx_entry_cast.types.Push(entry_cast_alloc);
            env.resolved_types_nested.Push(pfx_entry_cast);
        }
        
        mut out_cast_alloc_c := codegen.codegen_generate_expression(expr_cast_alloc_test, &env, ctx);
        os.LogStr(out_cast_alloc_c); // Expected: ((int)os_ArenaAlloc(&ctx, sizeof(ListNode)))
    }

    // Test Step 2 Recursion Detection Invariant Tests
    mut l_rec_test1: lexer.Lexer[ctx];
    lexer.init_lexer(&l_rec_test1, "func factorial(n: int) int { if n <= 1 { return 1; } return n * factorial(n - 1); }");
    mut p_rec_test1: parser.Parser[ctx];
    parser.init_parser(&p_rec_test1, &l_rec_test1, ctx);
    mut prog_rec_test1 := parser.parse_program(&p_rec_test1, ctx);
    unsafe {
        mut statements_vec := &ctx[prog_rec_test1.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut body := (*statements_vec)[0].FunctionDecl.body;
        mut is_rec := codegen.codegen_is_function_recursive(body, "factorial", ctx);
        os.LogInt(is_rec); // Expected: 1
    }

    mut l_rec_test2: lexer.Lexer[ctx];
    lexer.init_lexer(&l_rec_test2, "func non_recursive(n: int) int { return n + 1; }");
    mut p_rec_test2: parser.Parser[ctx];
    parser.init_parser(&p_rec_test2, &l_rec_test2, ctx);
    mut prog_rec_test2 := parser.parse_program(&p_rec_test2, ctx);
    unsafe {
        mut statements_vec := &ctx[prog_rec_test2.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut body := (*statements_vec)[0].FunctionDecl.body;
        mut is_rec := codegen.codegen_is_function_recursive(body, "non_recursive", ctx);
        os.LogInt(is_rec); // Expected: 0
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

      // Step 1: Verification Test for Brand Erasure Utilities
    mut t_branded_vect: ast.Type[ctx];
    t_branded_vect.tag = 8;
    t_branded_vect.Struct.struct_name = "std_Vector_str_ctx";
    mut brand_v_idx: Index[str, ctx] := empty[Index[str, ctx]];
    unsafe {
        brand_v_idx = os.ArenaAlloc(ctx) as Index[str, ctx];
        t_branded_vect.Struct.brand = brand_v_idx;
        mut brand_ptr := &ctx[t_branded_vect.Struct.brand] as *str;
        *brand_ptr = "ctx";
    }

    mut t_lookup: ast.Type[ctx];
    t_lookup.tag = 8;
    t_lookup.Struct.struct_name = "LookupResult_os_Dir_ctx";
    mut brand_l_idx: Index[str, ctx] := empty[Index[str, ctx]];
    unsafe {
        brand_l_idx = os.ArenaAlloc(ctx) as Index[str, ctx];
        t_lookup.Struct.brand = brand_l_idx;
        mut brand_ptr := &ctx[t_lookup.Struct.brand] as *str;
        *brand_ptr = "ctx";
    }

    mut erased_lookup := codegen.codegen_erase_type(t_lookup, &env, ctx);
    os.LogStr(erased_lookup.Struct.struct_name);

    // Step 2: Verification Test for C Type Generation
    mut t_gen_vector: ast.Type[ctx];
    t_gen_vector.tag = 10; // Generic
    t_gen_vector.Generic.name = "std.Vector";
    
    mut args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    
    mut arg1: ast.Type[ctx];
    arg1.tag = 5; // Str
    args.Push(arg1);
    
    mut arg2: ast.Type[ctx];
    arg2.tag = 8; // Struct
    arg2.Struct.struct_name = "ctx";
    arg2.Struct.brand = empty[Index[str, ctx]];
    args.Push(arg2);
    
    mut args_idx: Index[std.Vector[ast.Type[ctx], ctx], ctx] := os.ArenaAlloc(ctx);
    unsafe {
        mut args_ptr := &ctx[args_idx] as *std.Vector[ast.Type[ctx], ctx];
        *args_ptr = args;
    }
    t_gen_vector.Generic.args = args_idx;
    
    mut c_type_str := codegen.codegen_get_c_type(t_gen_vector, &env, ctx);
    os.LogStr(c_type_str);

    // Step 3: Verification Test for Struct Deduplication
    // Register MyNode_ctx1 and MyNode_ctx2
    mut env_dup := typechecker.env_new(ctx);
    
    mut layout1: typechecker.StructLayout[ctx];
    mut brand1: Index[str, ctx] := empty[Index[str, ctx]];
    unsafe {
        brand1 = os.ArenaAlloc(ctx) as Index[str, ctx];
        mut b_ptr := &ctx[brand1] as *str;
        *b_ptr = "ctx1";
    }
    layout1.brand = brand1;
    layout1.fields = std.HashMapNew(ctx);
    mut t_int_dup: ast.Type[ctx]; t_int_dup.tag = 0; // Int
    layout1.fields.Insert("val", t_int_dup);
    typechecker.env_register_struct(&env_dup, "MyNode_ctx1", layout1, ctx);

    mut layout2: typechecker.StructLayout[ctx];
    mut brand2: Index[str, ctx] := empty[Index[str, ctx]];
    unsafe {
        brand2 = os.ArenaAlloc(ctx) as Index[str, ctx];
        mut b_ptr := &ctx[brand2] as *str;
        *b_ptr = "ctx2";
    }
    layout2.brand = brand2;
    layout2.fields = std.HashMapNew(ctx);
    layout2.fields.Insert("val", t_int_dup);
    typechecker.env_register_struct(&env_dup, "MyNode_ctx2", layout2, ctx);

    // Generate full C output
    mut empty_prog_vec: std.Vector[ast.Program[ctx], ctx] := std.VectorNew(ctx);
    mut empty_prefixes: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut generated_c := codegen.codegen_generate(empty_prog_vec, empty_prefixes, &env_dup, ctx);

    // Assert that "struct MyNode {" is defined exactly once
    mut search_str := "struct MyNode {";
    mut first_idx := std.str_find(generated_c, search_str);
    if first_idx != 0 - 1 {
        mut remaining := std.str_slice(generated_c, first_idx + len(search_str), len(generated_c));
        mut second_idx := std.str_find(remaining, search_str);
        if second_idx == 0 - 1 {
            os.LogStr("Struct MyNode correctly defined exactly once!");
        } else {
            os.LogStr("ERROR: Struct MyNode defined more than once!");
        }
    } else {
        os.LogStr("ERROR: Struct MyNode not defined at all!");
    }

    // Step 1: Verification Test for codegen_gen_type_aware_initializer Erasure
    mut t_branded_prog: ast.Type[ctx];
    t_branded_prog.tag = 8;
    t_branded_prog.Struct.struct_name = "ast__Program_ctx";
    mut brand_prog_idx: Index[str, ctx] := os.ArenaAlloc(ctx);
    t_branded_prog.Struct.brand = brand_prog_idx;
    unsafe { 
        mut brand_ptr := &ctx[t_branded_prog.Struct.brand] as *str;
        *brand_ptr = "ctx";
    }

    // Register ast__Program in the struct registry of env
    mut program_layout: typechecker.StructLayout[ctx];
    program_layout.brand = empty[Index[str, ctx]];
    program_layout.fields = std.HashMapNew(ctx);
    typechecker.env_register_struct(&env, "ast__Program", program_layout, ctx);

    mut init_str := codegen.codegen_gen_type_aware_initializer(t_branded_prog, &env, ctx);
    os.LogStr(init_str);

    // Step 2: Verification Test for branded empty[MyNode[ctx]] expression
    mut l_empty_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_empty_test, "empty[MyNode[ctx]]");
    mut p_empty_test: parser.Parser[ctx];
    parser.init_parser(&p_empty_test, &l_empty_test, ctx);
    mut expr_empty_test := parser.parse_expression(&p_empty_test, 1, ctx);

    // Register MyNode in the struct registry of env
    mut mynode_layout: typechecker.StructLayout[ctx];
    mynode_layout.brand = empty[Index[str, ctx]];
    mynode_layout.fields = std.HashMapNew(ctx);
    typechecker.env_register_struct(&env, "MyNode", mynode_layout, ctx);

    mut empty_init_str := codegen.codegen_generate_expression(expr_empty_test, &env, ctx);
    os.LogStr(empty_init_str);

    // Step 1: Verification Test for os_GetThreadScratch forward declaration
    mut env_tl_test := typechecker.env_new(ctx);
    
    mut tl_layout: typechecker.StructLayout[ctx];
    tl_layout.brand = empty[Index[str, ctx]];
    tl_layout.fields = std.HashMapNew(ctx);
    typechecker.env_register_struct(&env_tl_test, "std_ThreadLocalContext", tl_layout, ctx);

    mut empty_prog_vec_tl: std.Vector[ast.Program[ctx], ctx] := std.VectorNew(ctx);
    mut empty_prefixes_tl: std.Vector[str, ctx] := std.VectorNew(ctx);
    mut gen_tl_c := codegen.codegen_generate(empty_prog_vec_tl, empty_prefixes_tl, &env_tl_test, ctx);

    mut tl_fwd_idx := std.str_find(gen_tl_c, "std_ThreadLocalContext os_GetThreadScratch(void);");
    if tl_fwd_idx != 0 - 1 {
        os.LogStr("os_GetThreadScratch forward declaration generated correctly!");
    } else {
        os.LogStr("ERROR: os_GetThreadScratch forward declaration missing!");
    }

    mut tl_def_idx := std.str_find(gen_tl_c, "std_ThreadLocalContext os_GetThreadScratch(void) {");
    if tl_def_idx != 0 - 1 {
        os.LogStr("os_GetThreadScratch function definition generated correctly!");
    } else {
        os.LogStr("ERROR: os_GetThreadScratch function definition missing!");
    }

    // Step 3: Verification Test for Step 1 Type & Container Identification Helpers
    mut t_slice_test: ast.Type[ctx];
    t_slice_test.tag = 6; // Slice
    os.LogInt(codegen.codegen_is_slice_type(t_slice_test)); // Expected: 1

    mut t_str_test: ast.Type[ctx];
    t_str_test.tag = 5; // Str
    os.LogInt(codegen.codegen_is_slice_type(t_str_test)); // Expected: 1

    mut t_vec_test: ast.Type[ctx];
    t_vec_test.tag = 8; // Struct
    t_vec_test.Struct.struct_name = "std_Vector_int_ctx";
    t_vec_test.Struct.brand = empty[Index[str, ctx]];
    os.LogInt(codegen.codegen_is_vector_type(t_vec_test, &env, ctx)); // Expected: 1

    // Sub-Step 1.1 Verification: Test codegen_is_vector_type and codegen_is_pool_type with RawPointer (tag 9)
    mut t_vec_ptr: ast.Type[ctx];
    t_vec_ptr.tag = 9; // RawPointer
    t_vec_ptr.RawPointer.inner = os.ArenaAlloc(ctx);
    ctx[t_vec_ptr.RawPointer.inner] = t_vec_test;
    os.LogInt(codegen.codegen_is_vector_type(t_vec_ptr, &env, ctx)); // Expected: 1

    mut t_pool_test: ast.Type[ctx];
    t_pool_test.tag = 8; // Struct
    t_pool_test.Struct.struct_name = "std_Pool_int_ctx";
    t_pool_test.Struct.brand = empty[Index[str, ctx]];

    mut t_pool_ptr: ast.Type[ctx];
    t_pool_ptr.tag = 9; // RawPointer
    t_pool_ptr.RawPointer.inner = os.ArenaAlloc(ctx);
    ctx[t_pool_ptr.RawPointer.inner] = t_pool_test;
    os.LogInt(codegen.codegen_is_pool_type(t_pool_ptr, &env, ctx)); // Expected: 1

    // Sub-Step 1.2 Verification: Test codegen_is_hashmap_type with RawPointer (tag 9)
    mut t_map_str_test: ast.Type[ctx];
    t_map_str_test.tag = 8; // Struct
    t_map_str_test.Struct.struct_name = "std_HashMap_str_int_ctx";
    t_map_str_test.Struct.brand = empty[Index[str, ctx]];
    
    // Register the standard std_HashMap_str_int_ctx layout
    mut map_str_layout: typechecker.StructLayout[ctx];
    map_str_layout.brand = empty[Index[str, ctx]];
    map_str_layout.fields = std.HashMapNew(ctx);
    
    mut keys_ptr_type: ast.Type[ctx];
    keys_ptr_type.tag = 9; // RawPointer
    keys_ptr_type.RawPointer.inner = os.ArenaAlloc(ctx);
    ctx[keys_ptr_type.RawPointer.inner].tag = 5; // Str
    
    map_str_layout.fields.Insert("keys", keys_ptr_type);
    typechecker.env_register_struct(&env, "std_HashMap_str_int_ctx", map_str_layout, ctx);
    
    os.LogInt(codegen.codegen_is_hashmap_type(t_map_str_test, &env, ctx)); // Expected: 1
    os.LogInt(codegen.codegen_hashmap_is_str_key(t_map_str_test, &env, ctx)); // Expected: 1

    mut t_map_ptr: ast.Type[ctx];
    t_map_ptr.tag = 9; // RawPointer
    t_map_ptr.RawPointer.inner = os.ArenaAlloc(ctx);
    ctx[t_map_ptr.RawPointer.inner] = t_map_str_test;
    os.LogInt(codegen.codegen_is_hashmap_type(t_map_ptr, &env, ctx)); // Expected: 1

    mut t_map_int_test: ast.Type[ctx];
    t_map_int_test.tag = 8; // Struct
    t_map_int_test.Struct.struct_name = "std_HashMap_int_int_ctx";
    t_map_int_test.Struct.brand = empty[Index[str, ctx]];

    // Register custom std_HashMap_int_int_ctx layout
    mut map_int_layout: typechecker.StructLayout[ctx];
    map_int_layout.brand = empty[Index[str, ctx]];
    map_int_layout.fields = std.HashMapNew(ctx);
    
    mut keys_int_ptr_type: ast.Type[ctx];
    keys_int_ptr_type.tag = 9; // RawPointer
    keys_int_ptr_type.RawPointer.inner = os.ArenaAlloc(ctx);
    ctx[keys_int_ptr_type.RawPointer.inner].tag = 0; // Int
    
    map_int_layout.fields.Insert("keys", keys_int_ptr_type);
    typechecker.env_register_struct(&env, "std_HashMap_int_int_ctx", map_int_layout, ctx);

    os.LogInt(codegen.codegen_is_hashmap_type(t_map_int_test, &env, ctx)); // Expected: 1
    os.LogInt(codegen.codegen_hashmap_is_str_key(t_map_int_test, &env, ctx)); // Expected: 0

    // Step 1 Verification: Test RawPointer dereferencing on Selector
    mut env_sel_test := typechecker.env_new(ctx);
    mut scope_sel_test := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    // Register a custom struct MyNode { val: bool }
    mut node_layout_test: typechecker.StructLayout[ctx];
    node_layout_test.brand = empty[Index[str, ctx]];
    node_layout_test.fields = std.HashMapNew(ctx);
    mut t_bool_test: ast.Type[ctx]; t_bool_test.tag = 2; // Bool
    node_layout_test.fields.Insert("val", t_bool_test);
    typechecker.env_register_struct(&env_sel_test, "MyNode", node_layout_test, ctx);

    // Variable p_node of type *MyNode
    mut t_node_struct_test := typechecker.make_type_struct("MyNode", "", ctx);
    mut t_node_ptr_test := typechecker.make_type_pointer(t_node_struct_test, ctx);
    typechecker.scope_insert(scope_sel_test, "p_node", t_node_ptr_test, ctx);

    // Parse selector expression: "p_node.val"
    mut l_sel_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_sel_test, "p_node.val");
    mut p_sel_test: parser.Parser[ctx];
    parser.init_parser(&p_sel_test, &l_sel_test, ctx);
    mut expr_sel_test := parser.parse_expression(&p_sel_test, 1, ctx);

    // Check expression
    mut evaluated_sel_t := typechecker.check_expression(expr_sel_test, &env_sel_test, scope_sel_test, ctx);
    os.LogStr(ast.serialize_type(evaluated_sel_t, ctx)); // Expected: Bool

    // Variable node of type MyNode
    typechecker.scope_insert(scope_sel_test, "node", t_node_struct_test, ctx);
    mut l_sel_val: lexer.Lexer[ctx];
    lexer.init_lexer(&l_sel_val, "node.val");
    mut p_sel_val: parser.Parser[ctx];
    parser.init_parser(&p_sel_val, &l_sel_val, ctx);
    mut expr_sel_val := parser.parse_expression(&p_sel_val, 1, ctx);
    mut evaluated_sel_val := typechecker.check_expression(expr_sel_val, &env_sel_test, scope_sel_test, ctx);

    // Generate C code for both (Step 2 Verification)
    mut c_sel_test := codegen.codegen_generate_expression(expr_sel_test, &env_sel_test, ctx);
    os.LogStr(c_sel_test); // Expected: p_node->val
    
    mut c_sel_val := codegen.codegen_generate_expression(expr_sel_val, &env_sel_test, ctx);
    os.LogStr(c_sel_val); // Expected: node.val

    // Step 4: Verification Test for Step 2 Slice, Str, and RawPointer IndexAccess Branches
    mut e_slice_access: ast.Expression[ctx];
    e_slice_access.tag = 8; // IndexAccess
    e_slice_access.IndexAccess.allocator = os.ArenaAlloc(ctx);
    e_slice_access.IndexAccess.index = os.ArenaAlloc(ctx);
    
    // Set allocator as identifier "my_slice"
    ctx[e_slice_access.IndexAccess.allocator].tag = 0; // Identifier
    ctx[e_slice_access.IndexAccess.allocator].Identifier.span.start.offset = 100;
    ctx[e_slice_access.IndexAccess.allocator].Identifier.span.end.offset = 108;

    // Set index as integer 2
    ctx[e_slice_access.IndexAccess.index].tag = 1; // Integer
    ctx[e_slice_access.IndexAccess.index].Integer.val = 2;
    ctx[e_slice_access.IndexAccess.index].Integer.span.start.offset = 109;
    ctx[e_slice_access.IndexAccess.index].Integer.span.end.offset = 110;

    e_slice_access.IndexAccess.span.start.offset = 100;
    e_slice_access.IndexAccess.span.end.offset = 111;

    // Setup types in env
    mut t_slice: ast.Type[ctx];
    t_slice.tag = 6; // Slice
    t_slice.Slice.inner = os.ArenaAlloc(ctx);
    ctx[t_slice.Slice.inner].tag = 0; // Int

    mut t_int_test: ast.Type[ctx];
    t_int_test.tag = 0; // Int

    mut entry_slice: typechecker.ResolvedTypeEntry[ctx];
    entry_slice.start_offset = 100;
    entry_slice.end_offset = 108;
    entry_slice.val_type = t_slice;

    mut entry_idx: typechecker.ResolvedTypeEntry[ctx];
    entry_idx.start_offset = 109;
    entry_idx.end_offset = 110;
    entry_idx.val_type = t_int_test;

    mut pfx_entry2: typechecker.PrefixMapEntry[ctx];
    pfx_entry2.prefix = "";
    pfx_entry2.types = std.VectorNew(ctx);
    pfx_entry2.types.Push(entry_slice);
    pfx_entry2.types.Push(entry_idx);
    env.resolved_types_nested.Push(pfx_entry2);

    mut expr_slice_access_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx[expr_slice_access_idx] = e_slice_access;
    mut slice_gen_str := codegen.codegen_generate_expression(expr_slice_access_idx, &env, ctx);
    os.LogStr(slice_gen_str); // Expected: (*({ if (2 < 0 || 2 >= my_slice.len) { printf("Slice bounds check failed at line %d\n", __LINE__); exit(1); } &(my_slice.data[2]); }))

    // Test RawPointer index access
    mut e_ptr_access: ast.Expression[ctx];
    e_ptr_access.tag = 8; // IndexAccess
    e_ptr_access.IndexAccess.allocator = os.ArenaAlloc(ctx);
    e_ptr_access.IndexAccess.index = os.ArenaAlloc(ctx);

    ctx[e_ptr_access.IndexAccess.allocator].tag = 0; // Identifier
    ctx[e_ptr_access.IndexAccess.allocator].Identifier.name = "my_ptr";
    ctx[e_ptr_access.IndexAccess.allocator].Identifier.span.start.offset = 200;
    ctx[e_ptr_access.IndexAccess.allocator].Identifier.span.end.offset = 206;

    ctx[e_ptr_access.IndexAccess.index].tag = 1; // Integer
    ctx[e_ptr_access.IndexAccess.index].Integer.val = 3;
    ctx[e_ptr_access.IndexAccess.index].Integer.span.start.offset = 207;
    ctx[e_ptr_access.IndexAccess.index].Integer.span.end.offset = 208;

    e_ptr_access.IndexAccess.span.start.offset = 200;
    e_ptr_access.IndexAccess.span.end.offset = 209;

    mut t_ptr_test: ast.Type[ctx];
    t_ptr_test.tag = 9; // RawPointer
    t_ptr_test.RawPointer.inner = os.ArenaAlloc(ctx);
    ctx[t_ptr_test.RawPointer.inner].tag = 0; // Int

    mut entry_ptr: typechecker.ResolvedTypeEntry[ctx];
    entry_ptr.start_offset = 200;
    entry_ptr.end_offset = 206;
    entry_ptr.val_type = t_ptr_test;

    mut entry_idx2: typechecker.ResolvedTypeEntry[ctx];
    entry_idx2.start_offset = 207;
    entry_idx2.end_offset = 208;
    entry_idx2.val_type = t_int_test;

    mut pfx_entry3: typechecker.PrefixMapEntry[ctx];
    pfx_entry3.prefix = "";
    pfx_entry3.types = std.VectorNew(ctx);
    pfx_entry3.types.Push(entry_ptr);
    pfx_entry3.types.Push(entry_idx2);
    env.resolved_types_nested.Push(pfx_entry3);

    mut expr_ptr_access_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx[expr_ptr_access_idx] = e_ptr_access;
    mut ptr_gen_str := codegen.codegen_generate_expression(expr_ptr_access_idx, &env, ctx);
    os.LogStr(ptr_gen_str); // Expected: (my_ptr[3])

    // Step 5: Verification Test for Step 3 Vector, Pool, and HashMap IndexAccess Branches
    // 1. Vector indexing test
    mut e_vec_access: ast.Expression[ctx];
    e_vec_access.tag = 8; // IndexAccess
    e_vec_access.IndexAccess.allocator = os.ArenaAlloc(ctx);
    e_vec_access.IndexAccess.index = os.ArenaAlloc(ctx);
    
    // Set allocator as identifier "my_vec"
    ctx[e_vec_access.IndexAccess.allocator].tag = 0; // Identifier
    ctx[e_vec_access.IndexAccess.allocator].Identifier.name = "my_vec";
    ctx[e_vec_access.IndexAccess.allocator].Identifier.span.start.offset = 300;
    ctx[e_vec_access.IndexAccess.allocator].Identifier.span.end.offset = 306;

    // Set index as integer 4
    ctx[e_vec_access.IndexAccess.index].tag = 1; // Integer
    ctx[e_vec_access.IndexAccess.index].Integer.val = 4;
    ctx[e_vec_access.IndexAccess.index].Integer.span.start.offset = 307;
    ctx[e_vec_access.IndexAccess.index].Integer.span.end.offset = 308;

    e_vec_access.IndexAccess.span.start.offset = 300;
    e_vec_access.IndexAccess.span.end.offset = 309;

    mut t_vec: ast.Type[ctx];
    t_vec.tag = 8; // Struct
    t_vec.Struct.struct_name = "std_Vector_int_ctx";
    t_vec.Struct.brand = empty[Index[str, ctx]];

    mut entry_vec: typechecker.ResolvedTypeEntry[ctx];
    entry_vec.start_offset = 300;
    entry_vec.end_offset = 306;
    entry_vec.val_type = t_vec;

    mut pfx_entry_vec: typechecker.PrefixMapEntry[ctx];
    pfx_entry_vec.prefix = "";
    pfx_entry_vec.types = std.VectorNew(ctx);
    pfx_entry_vec.types.Push(entry_vec);
    env.resolved_types_nested.Push(pfx_entry_vec);

    mut expr_vec_access_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx[expr_vec_access_idx] = e_vec_access;
    mut vec_gen_str := codegen.codegen_generate_expression(expr_vec_access_idx, &env, ctx);
    os.LogStr(vec_gen_str); // Expected: (*({ if (4 < 0 || 4 >= my_vec.len) { printf("Vector bounds check failed at line %d\n", __LINE__); exit(1); } &(my_slice.data[2]); }))

    // Test HashMap index access
    mut e_map_access: ast.Expression[ctx];
    e_map_access.tag = 8; // IndexAccess
    e_map_access.IndexAccess.allocator = os.ArenaAlloc(ctx);
    e_map_access.IndexAccess.index = os.ArenaAlloc(ctx);

    ctx[e_map_access.IndexAccess.allocator].tag = 0; // Identifier
    ctx[e_map_access.IndexAccess.allocator].Identifier.name = "my_map";
    ctx[e_map_access.IndexAccess.allocator].Identifier.span.start.offset = 400;
    ctx[e_map_access.IndexAccess.allocator].Identifier.span.end.offset = 406;

    ctx[e_map_access.IndexAccess.index].tag = 0; // Identifier
    ctx[e_map_access.IndexAccess.index].Identifier.name = "my_key";
    ctx[e_map_access.IndexAccess.index].Identifier.span.start.offset = 407;
    ctx[e_map_access.IndexAccess.index].Identifier.span.end.offset = 413;

    e_map_access.IndexAccess.span.start.offset = 400;
    e_map_access.IndexAccess.span.end.offset = 414;

    mut t_map: ast.Type[ctx];
    t_map.tag = 8; // Struct
    t_map.Struct.struct_name = "std_HashMap_str_int_ctx";
    t_map.Struct.brand = empty[Index[str, ctx]];

    mut entry_map: typechecker.ResolvedTypeEntry[ctx];
    entry_map.start_offset = 400;
    entry_map.end_offset = 406;
    entry_map.val_type = t_map;

    mut pfx_entry_map: typechecker.PrefixMapEntry[ctx];
    pfx_entry_map.prefix = "";
    pfx_entry_map.types = std.VectorNew(ctx);
    pfx_entry_map.types.Push(entry_map);
    env.resolved_types_nested.Push(pfx_entry_map);

    mut expr_map_access_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx[expr_map_access_idx] = e_map_access;
    mut map_gen_str := codegen.codegen_generate_expression(expr_map_access_idx, &env, ctx);
    os.LogStr(map_gen_str); // Expected: (*os_HashMapRef(&my_map, my_key, 1))

    // Test Step 1.3: UnsafeBlock (Tag 10) statement transpilation
    mut l_step1_3_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_step1_3_test, "unsafe { mut x := 42; }");
    mut p_step1_3_test: parser.Parser[ctx];
    parser.init_parser(&p_step1_3_test, &l_step1_3_test, ctx);
    mut prog_step1_3_test := parser.parse_program(&p_step1_3_test, ctx);
    unsafe {
        mut unsafe_test_statements_vec := &ctx[prog_step1_3_test.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut unsafe_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[unsafe_stmt_idx] = (*unsafe_test_statements_vec)[0];

        // Register the variable 'x' as type Int (0) to allow type resolution inside codegen
        mut unsafe_test_body_idx := ctx[unsafe_stmt_idx].UnsafeBlock.body;
        mut unsafe_test_body_statements := &ctx[ctx[unsafe_test_body_idx].statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut unsafe_test_var_decl := (*unsafe_test_body_statements)[0];
        mut unsafe_test_var_decl_span := unsafe_test_var_decl.VarDecl.span;

        mut unsafe_test_t_int: ast.Type[ctx];
        unsafe_test_t_int.tag = 0; // Int

        mut unsafe_test_entry: typechecker.ResolvedTypeEntry[ctx];
        unsafe_test_entry.start_offset = unsafe_test_var_decl_span.start.offset;
        unsafe_test_entry.end_offset = unsafe_test_var_decl_span.end.offset;
        unsafe_test_entry.val_type = unsafe_test_t_int;

        mut unsafe_test_found_idx := 0 - 1;
        mut unsafe_test_p_idx := 0;
        while unsafe_test_p_idx < len(env.resolved_types_nested) {
            if std.str_eq(env.resolved_types_nested[unsafe_test_p_idx].prefix, "") {
                unsafe_test_found_idx = unsafe_test_p_idx;
            }
            unsafe_test_p_idx = unsafe_test_p_idx + 1;
        }
        if unsafe_test_found_idx != 0 - 1 {
            mut unsafe_test_entry_ref := &env.resolved_types_nested[unsafe_test_found_idx];
            (*unsafe_test_entry_ref).types.Push(unsafe_test_entry);
        }

        mut unsafe_test_c := codegen.codegen_generate_statement(unsafe_stmt_idx, &env, ctx);
        os.LogStr(unsafe_test_c); // Expected: 
                                  //     {
                                  //         int x = 42;
                                  //     }
    }

    // Test Step 2.1: While Statement (Tag 6) statement transpilation
    mut l_while_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_while_test, "while x < 10 { x = x + 1; }");
    mut p_while_test: parser.Parser[ctx];
    parser.init_parser(&p_while_test, &l_while_test, ctx);
    mut prog_while_test := parser.parse_program(&p_while_test, ctx);
    unsafe {
        mut while_test_statements_vec := &ctx[prog_while_test.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut while_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[while_stmt_idx] = (*while_test_statements_vec)[0];

        mut t_int: ast.Type[ctx];
        t_int.tag = 0; // Int
        
        env.variable_types.Insert("x", t_int);

        mut while_c := codegen.codegen_generate_statement(while_stmt_idx, &env, ctx);
        os.LogStr(while_c); // Expected:
                            //     while ((x < 10)) {
                            //         if (GUST_UNLIKELY(--gust_loop_ticks <= 0)) { gust_loop_ticks = GUST_TICK_INTERVAL; gust_yield(); }
                            //         x = (x + 1);
                            //     }
    }

    // Test Step 3: Recursive Function Prologue Injection
    mut l_rec_gen: lexer.Lexer[ctx];
    lexer.init_lexer(&l_rec_gen, "func recurse(n: int) int { return recurse(n - 1); }");
    mut p_rec_gen: parser.Parser[ctx];
    parser.init_parser(&p_rec_gen, &l_rec_gen, ctx);
    mut prog_rec_gen := parser.parse_program(&p_rec_gen, ctx);
    unsafe {
        mut statements_vec := &ctx[prog_rec_gen.statements] as *std.Vector[ast.Statement[ctx], ctx];
        typechecker.env_pre_register_statement(&env, (*statements_vec)[0], ctx);
        mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[stmt_idx] = (*statements_vec)[0];
        mut rec_c := codegen.codegen_generate_statement(stmt_idx, &env, ctx);
        os.LogStr(rec_c); // Expected prologue: if (GUST_UNLIKELY(--gust_loop_ticks <= 0)) { ... }
    }

    // Test Step 2.2: If Statement (Tag 7) statement transpilation (Consequence block only)
    mut l_if_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_if_test, "if active { val = 1; }");
    mut p_if_test: parser.Parser[ctx];
    parser.init_parser(&p_if_test, &l_if_test, ctx);
    mut prog_if_test := parser.parse_program(&p_if_test, ctx);
    unsafe {
        mut if_test_statements_vec := &ctx[prog_if_test.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut if_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[if_stmt_idx] = (*if_test_statements_vec)[0];

        mut t_bool: ast.Type[ctx];
        t_bool.tag = 2; // Bool

        mut t_int: ast.Type[ctx];
        t_int.tag = 0; // Int

        env.variable_types.Insert("active", t_bool);
        env.variable_types.Insert("val", t_int);

        mut if_c := codegen.codegen_generate_statement(if_stmt_idx, &env, ctx);
        os.LogStr(if_c); // Expected:
                         //     if (active) {
                         //         val = 1;
                         //     }
    }

    // Test Step 2.3: If-Else Statement (Tag 7) statement transpilation
    mut l_ifelse_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_ifelse_test, "if x == 1 { y = 10; } else { y = 20; }");
    mut p_ifelse_test: parser.Parser[ctx];
    parser.init_parser(&p_ifelse_test, &l_ifelse_test, ctx);
    mut prog_ifelse_test := parser.parse_program(&p_ifelse_test, ctx);
    unsafe { 
        mut ifelse_test_statements_vec := &ctx[prog_ifelse_test.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut ifelse_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[ifelse_stmt_idx] = (*ifelse_test_statements_vec)[0];

        mut t_int: ast.Type[ctx];
        t_int.tag = 0; // Int

        env.variable_types.Insert("x", t_int);
        env.variable_types.Insert("y", t_int);

        mut ifelse_c := codegen.codegen_generate_statement(ifelse_stmt_idx, &env, ctx);
        os.LogStr(ifelse_c); // Expected:
                             //     if ((x == 1)) {
                             //         y = 10;
                             //     } else {
                             //         y = 20;
                             //     }
    }

    // Test Step 3.1: Defer Statement (Tag 11) LIFO Block-level statement transpilation
    mut l_defer_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_defer_test, "while 1 {\n    defer cleanup_first();\n    mut x := 1;\n    defer cleanup_second();\n}");
    mut p_defer_test: parser.Parser[ctx];
    parser.init_parser(&p_defer_test, &l_defer_test, ctx);
    mut prog_defer_test := parser.parse_program(&p_defer_test, ctx);
    unsafe {
        mut defer_test_statements_vec := &ctx[prog_defer_test.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut while_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[while_stmt_idx] = (*defer_test_statements_vec)[0];

        mut t_int: ast.Type[ctx];
        t_int.tag = 0; // Int
        env.variable_types.Insert("x", t_int);

        // Register the dummy function signatures
        mut sig_cleanup_first: typechecker.FunctionSignature[ctx];
        sig_cleanup_first.param_names = std.VectorNew(ctx);
        sig_cleanup_first.params = std.VectorNew(ctx);
        sig_cleanup_first.return_type.tag = 3; // Void
        env.function_registry.Insert("cleanup_first", sig_cleanup_first);

        mut sig_cleanup_second: typechecker.FunctionSignature[ctx];
        sig_cleanup_second.param_names = std.VectorNew(ctx); 
        sig_cleanup_second.params = std.VectorNew(ctx);
        sig_cleanup_second.return_type.tag = 3; // Void
        env.function_registry.Insert("cleanup_second", sig_cleanup_second);

        mut defer_c := codegen.codegen_generate_statement(while_stmt_idx, &env, ctx);
        os.LogStr(defer_c); // Expected:
                            //     while (1) {
                            //         int x = 1;
                            //         cleanup_second();
                            //         cleanup_first();
                            //     }
    }

    // Test Step 3.2: Defer Statement (Tag 11) individual statement transpilation (Safe fallback)
    mut l_defer_single: lexer.Lexer[ctx];
    lexer.init_lexer(&l_defer_single, "defer cleanup_first();");
    mut p_defer_single: parser.Parser[ctx];
    parser.init_parser(&p_defer_single, &l_defer_single, ctx);
    mut prog_defer_single := parser.parse_program(&p_defer_single, ctx);
    unsafe {
        mut defer_single_vec := &ctx[prog_defer_single.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut defer_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[defer_stmt_idx] = (*defer_single_vec)[0];

        mut defer_single_c := codegen.codegen_generate_statement(defer_stmt_idx, &env, ctx);
        os.LogStr(defer_single_c); // Expected: ""
    }

    // Test Step 4.1: Match Statement (Tag 8) switch frame and tag mapping
    mut l_match_test: lexer.Lexer[ctx];
    lexer.init_lexer(&l_match_test, "type Status enum { Pending, Failed }");
    mut p_match_test: parser.Parser[ctx];
    parser.init_parser(&p_match_test, &l_match_test, ctx);
    mut prog_enum_test := parser.parse_program(&p_match_test, ctx);
    unsafe {
        mut enum_test_statements_vec := &ctx[prog_enum_test.statements] as *std.Vector[ast.Statement[ctx], ctx];
        typechecker.env_pre_register_statement(&env, (*enum_test_statements_vec)[0], ctx);
    }

    mut l_match_stmt: lexer.Lexer[ctx];
    lexer.init_lexer(&l_match_stmt, "match s { Pending => { os.Exit(0); }, Failed => { os.Exit(1); } }");
    mut p_match_stmt: parser.Parser[ctx];
    parser.init_parser(&p_match_stmt, &l_match_stmt, ctx);
    mut prog_match_test := parser.parse_program(&p_match_stmt, ctx);
    unsafe {
        mut match_test_statements_vec := &ctx[prog_match_test.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut match_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[match_stmt_idx] = (*match_test_statements_vec)[0];

        mut expr_idx := ctx[match_stmt_idx].Match.expression;
        mut expr_span := parser.get_expression_span(expr_idx, ctx);

        mut t_status: ast.Type[ctx];
        t_status.tag = 8; // Struct
        t_status.Struct.struct_name = "Status";
        t_status.Struct.brand = empty[Index[str, ctx]];

        mut match_entry_status: typechecker.ResolvedTypeEntry[ctx];
        match_entry_status.start_offset = expr_span.start.offset;
        match_entry_status.end_offset = expr_span.end.offset;
        match_entry_status.val_type = t_status;

        mut found_nested_idx := 0 - 1;
        mut idx_nested := 0;
        while idx_nested < len(env.resolved_types_nested) {
            if std.str_eq(env.resolved_types_nested[idx_nested].prefix, "") == 1 {
                found_nested_idx = idx_nested;
            }
            idx_nested = idx_nested + 1;
        }
        if found_nested_idx != 0 - 1 { 
            mut match_entry_ref := &env.resolved_types_nested[found_nested_idx];
            (*match_entry_ref).types.Push(match_entry_status);
        } else {
            mut pfx_entry: typechecker.PrefixMapEntry[ctx];
            pfx_entry.prefix = "";
            pfx_entry.types = std.VectorNew(ctx);
            pfx_entry.types.Push(match_entry_status);
            env.resolved_types_nested.Push(pfx_entry);
        }

        env.variable_types.Insert("s", t_status);

        mut match_c := codegen.codegen_generate_statement(match_stmt_idx, &env, ctx);
        os.LogStr(match_c); // Expected:
                            //     switch (s.tag) {
                            //         case Status_Tag__Pending: {
                            //             os_Exit(0);
                            //             break;
                            //         }
                            //         case Status_Tag__Failed: {
                            //             os_Exit(1);
                            //             break;
                            //         }
                            //     }
    }

    // Test Step 4.2: Match Statement (Tag 8) local variable destructuring and binding generation
    mut l_match_test_4_2: lexer.Lexer[ctx];
    lexer.init_lexer(&l_match_test_4_2, "type Shape enum { Circle { radius: int } }");
    mut p_match_test_4_2: parser.Parser[ctx];
    parser.init_parser(&p_match_test_4_2, &l_match_test_4_2, ctx);
    mut prog_enum_test_4_2 := parser.parse_program(&p_match_test_4_2, ctx);
    unsafe {
        mut enum_test_statements_vec := &ctx[prog_enum_test_4_2.statements] as *std.Vector[ast.Statement[ctx], ctx];
        typechecker.env_pre_register_statement(&env, (*enum_test_statements_vec)[0], ctx);
    }

    mut l_match_stmt_4_2: lexer.Lexer[ctx];
    lexer.init_lexer(&l_match_stmt_4_2, "match s { Circle { radius } => { os.LogInt(radius); } }");
    mut p_match_stmt_4_2: parser.Parser[ctx];
    parser.init_parser(&p_match_stmt_4_2, &l_match_stmt_4_2, ctx);
    mut prog_match_test_4_2 := parser.parse_program(&p_match_stmt_4_2, ctx);
    unsafe {
        mut match_test_statements_vec := &ctx[prog_match_test_4_2.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut match_stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx[match_stmt_idx] = (*match_test_statements_vec)[0];

        mut expr_idx := ctx[match_stmt_idx].Match.expression;
        mut expr_span := parser.get_expression_span(expr_idx, ctx);

        mut t_shape: ast.Type[ctx];
        t_shape.tag = 8; // Struct
        t_shape.Struct.struct_name = "Shape";
        t_shape.Struct.brand = empty[Index[str, ctx]];

        mut match_entry_status_4_2: typechecker.ResolvedTypeEntry[ctx];
        match_entry_status_4_2.start_offset = expr_span.start.offset;
        match_entry_status_4_2.end_offset = expr_span.end.offset;
        match_entry_status_4_2.val_type = t_shape;

        mut found_nested_idx := 0 - 1;
        mut idx_nested := 0;
        while idx_nested < len(env.resolved_types_nested) {
            if std.str_eq(env.resolved_types_nested[idx_nested].prefix, "") == 1 {
                found_nested_idx = idx_nested;
            }
            idx_nested = idx_nested + 1;
        }
        if found_nested_idx != 0 - 1 {
            mut match_entry_ref_4_2 := &env.resolved_types_nested[found_nested_idx];
            (*match_entry_ref_4_2).types.Push(match_entry_status_4_2);
        } else {
            mut pfx_entry: typechecker.PrefixMapEntry[ctx];
            pfx_entry.prefix = "";
            pfx_entry.types = std.VectorNew(ctx);
            pfx_entry.types.Push(match_entry_status_4_2);
            env.resolved_types_nested.Push(pfx_entry);
        }

        env.variable_types.Insert("s", t_shape);

        mut t_int: ast.Type[ctx];
        t_int.tag = 0; // Int
        env.variable_types.Insert("radius", t_int);

        mut match_c := codegen.codegen_generate_statement(match_stmt_idx, &env, ctx);
        os.LogStr(match_c); // Expected:
                            //     switch (s.tag) {
                            //         case Shape_Tag__Circle: {
                            //             int radius = s.Circle.radius;
                            //             os_LogInt(radius);
                            //             break;
                            //         }
                            //     }
    }
}
