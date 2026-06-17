import "ast.gst" as ast;
import "typechecker.gst" as typechecker;
import "lexer.gst" as lexer;
import "parser.gst" as parser;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut env := typechecker.env_new(ctx);

    // 1. Monomorphize Vector[int, ctx]
    mut vec_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    vec_args.Push(typechecker.make_type_int());
    vec_args.Push(typechecker.make_type_struct("ctx", "", ctx));

    mut vec_res := typechecker.monomorphize(&env, "std.Vector", vec_args, ctx);
     if vec_res.tag == 0 {
         mut concrete_t := vec_res.Ok.val;
         os.LogStr(std.Concat("Monomorphized Vector name: ", concrete_t.Struct.struct_name));

         guard layout := env.struct_registry.Get(concrete_t.Struct.struct_name) else {
             return;
         }
         os.LogInt(layout.fields.len);
     } else {
         os.LogStr("Vector monomorphization failed");
     }

    // 2. Parse and Register Custom Enum Template Result[T, ctx]
    mut l: lexer.Lexer[ctx];
    lexer.init_lexer(&l, "type Result[T, ctx] enum { Ok { val: T }, Err { val: int } }");

    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &l, ctx);

    mut prog := parser.parse_program(&p, ctx);
    unsafe {
        mut statements_vec := &ctx[prog.statements] as *std.Vector[ast.Statement[ctx], ctx];
        typechecker.env_pre_register_statement(&env, (*statements_vec)[0], ctx);
    }

    // Monomorphize Result[str, ctx]
    mut res_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    res_args.Push(typechecker.make_type_str());
    res_args.Push(typechecker.make_type_struct("ctx", "", ctx));

    mut mono_res := typechecker.monomorphize(&env, "Result", res_args, ctx);
    if mono_res.tag == 0 {
        mut concrete_t := mono_res.Ok.val;
        os.LogStr(std.Concat("Monomorphized Result name: ", concrete_t.Struct.struct_name));

        guard parent_layout := env.struct_registry.Get(concrete_t.Struct.struct_name) else {
            return;
        }
        os.LogInt(parent_layout.fields.len);

        // Verify sub-variant structure
        guard ok_variant_t := parent_layout.fields.Get("Ok") else {
            return;
        }
        guard ok_layout := env.struct_registry.Get(ok_variant_t.Struct.struct_name) else {
            return;
        }
        guard val_field_t := ok_layout.fields.Get("val") else {
            return;
        }
        os.LogStr(std.Concat("Ok variant field type tag: ", std.FormatInt(val_field_t.tag)));
    } else {
        os.LogStr("Result monomorphization failed");
    }

    // 3. Parse and typecheck a small mock program with variable declarations and an enum
    mut l3: lexer.Lexer[ctx];
    lexer.init_lexer(&l3, "type Status enum { Active, Inactive } func main() { mut x: int := 10; }");

    mut p3: parser.Parser[ctx];
    parser.init_parser(&p3, &l3, ctx);

    mut prog3 := parser.parse_program(&p3, ctx);
    if len(p3.errors) > 0 {
        os.LogStr("ParserError in step 3");
        os.Exit(1);
    }

    mut scope3 := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);

    unsafe {
        mut statements_vec := &ctx[prog3.statements] as *std.Vector[ast.Statement[ctx], ctx];
        
        mut i := 0;
        while i < len(*statements_vec) {
            typechecker.env_pre_register_statement(&env, (*statements_vec)[i], ctx);
            i = i + 1;
        }

        mut j := 0;
        while j < len(*statements_vec) {
            mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[stmt_idx] = (*statements_vec)[j];
            typechecker.check_statement(stmt_idx, &env, scope3, ctx);
            j = j + 1;
        }
    }

    // 3.5 Intentionally trigger a type violation to verify the ❌ trace
    mut l4_error: lexer.Lexer[ctx];
    lexer.init_lexer(&l4_error, "func main() { mut y: int := \"not_an_int\"; }");

    mut p4_error: parser.Parser[ctx];
    parser.init_parser(&p4_error, &l4_error, ctx);

    mut prog4_error := parser.parse_program(&p4_error, ctx);
    if len(p4_error.errors) > 0 {
        os.LogStr("ParserError in error test");
        os.Exit(1);
    }

    mut scope4_error := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    unsafe {
        mut statements_vec := &ctx[prog4_error.statements] as *std.Vector[ast.Statement[ctx], ctx];
        
        mut i := 0;
        while i < len(*statements_vec) {
            typechecker.env_pre_register_statement(&env, (*statements_vec)[i], ctx);
            i = i + 1;
        }

        mut j := 0;
        while j < len(*statements_vec) {
            mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
            ctx[stmt_idx] = (*statements_vec)[j];
            typechecker.check_statement(stmt_idx, &env, scope4_error, ctx);
            j = j + 1;
        }
    }

    // Verify lookup of variables and enums inside registries
    mut lookup_var := env.variable_types.Get("x");
    if lookup_var.Ok {
        os.LogStr(std.Concat("variable_types lookup ok, type tag: ", std.FormatInt(lookup_var.Val.tag)));
    } else {
        os.LogStr("variable_types lookup failed");
    }

    // Verify that the variable declaration is registered in resolved_types (Phase 1 Fix)
    unsafe {
        mut statements_vec := &ctx[prog3.statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut main_decl := (*statements_vec)[1];
        mut body_idx := main_decl.FunctionDecl.body;
        mut body_stmts := &ctx[ctx[body_idx].statements] as *std.Vector[ast.Statement[ctx], ctx];
        mut var_decl := (*body_stmts)[0];
        
        mut span := var_decl.VarDecl.span;
        
        mut found_idx := 0 - 1;
        mut i := 0;
        while i < len(env.resolved_types_nested) {
            mut entry := env.resolved_types_nested[i];
            if std.str_eq(entry.prefix, "") {
                found_idx = i;
                i = len(env.resolved_types_nested);
            }
            i = i + 1;
        }
        
        mut lookup_resolved_ok := 0;
        mut lookup_resolved_val: ast.Type[ctx];
        if found_idx != 0 - 1 {
            mut entry_ref := &env.resolved_types_nested[found_idx];
            mut j := 0;
            while j < len((*entry_ref).types) {
                mut t_entry := (*entry_ref).types[j];
                if t_entry.start_offset == span.start.offset && t_entry.end_offset == span.end.offset {
                    lookup_resolved_val = t_entry.val_type;
                    lookup_resolved_ok = 1;
                    j = len((*entry_ref).types);
                }
                j = j + 1;
            }
        }
        
        if lookup_resolved_ok == 1 {
            os.LogStr("resolved_types lookup ok!");
            if typechecker.types_match(typechecker.make_type_int(), lookup_resolved_val, ctx) == 1 {
                os.LogStr("resolved_types type is Int ok!");
            } else {
                os.LogStr("resolved_types type mismatch!");
            }
        } else {
            os.LogStr("resolved_types lookup failed!");
        }
    }

    mut lookup_enum := env.enum_registry.Get("Status");
    if lookup_enum.Ok {
        os.LogStr(std.Concat("enum_registry lookup ok, variants count: ", std.FormatInt(len(lookup_enum.Val))));
    } else {
        os.LogStr("enum_registry lookup failed");
    }

    // 4. Test Key Sorting Utility (Step 2.2 Verification)
    mut test_map: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
    test_map.Insert("banana", 1);
    test_map.Insert("apple", 2);
    test_map.Insert("cherry", 3);

    mut sorted_keys := typechecker.typechecker_get_sorted_keys_int(&test_map, ctx);
    os.LogStr(std.Concat("Sorted keys count: ", std.FormatInt(len(sorted_keys))));
    mut k_idx := 0;
    while k_idx < len(sorted_keys) {
        os.LogStr(std.Concat("Sorted key: ", sorted_keys[k_idx]));
        k_idx = k_idx + 1;
    }

    // 5. Test Pointer-Safe Vector Sorting (Step 2.2.1 Verification)
    mut test_vec: std.Vector[str, ctx] := std.VectorNew(ctx);
    test_vec.Push("cherry");
    test_vec.Push("banana");
    test_vec.Push("apple");

    typechecker.typechecker_sort_vector_str(&test_vec, ctx);
    os.LogStr(std.Concat("Sorted vector count: ", std.FormatInt(len(test_vec))));
    mut v_idx := 0;
    while v_idx < len(test_vec) {
        os.LogStr(std.Concat("Sorted vector element: ", test_vec[v_idx]));
        v_idx = v_idx + 1;
    }

    // 6. Test Complete Environment Serializer (Step 2.5 Verification)
    mut full_dump := typechecker.typechecker_serialize_type_environment(&env, ctx);
    os.LogStr(full_dump);

    // 7. Test Recursive Monomorphization Cycle Detection
    mut l6: lexer.Lexer[ctx];
    lexer.init_lexer(&l6, "type Loop1[ctx] struct { val: Loop1[ctx] }");

    mut p6: parser.Parser[ctx];
    parser.init_parser(&p6, &l6, ctx);

    mut prog6 := parser.parse_program(&p6, ctx);
    unsafe {
        mut statements_vec := &ctx[prog6.statements] as *std.Vector[ast.Statement[ctx], ctx];
        typechecker.env_pre_register_statement(&env, (*statements_vec)[0], ctx);
    }

    mut loop_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    loop_args.Push(typechecker.make_type_struct("ctx", "", ctx));

    mut loop_res := typechecker.monomorphize(&env, "Loop1", loop_args, ctx);
    if loop_res.tag == 1 { // Err
        os.LogStr("Cycle Detection OK: Loop1 directly by-value rejected");
    } else {
        os.LogStr("Cycle Detection FAIL: Loop1 directly by-value accepted");
    }

    mut l7: lexer.Lexer[ctx];
    lexer.init_lexer(&l7, "type Loop2[ctx] struct { next: *Loop2[ctx] }");

    mut p7: parser.Parser[ctx];
    parser.init_parser(&p7, &l7, ctx);

    mut prog7 := parser.parse_program(&p7, ctx);
    unsafe {
        mut statements_vec := &ctx[prog7.statements] as *std.Vector[ast.Statement[ctx], ctx];
        typechecker.env_pre_register_statement(&env, (*statements_vec)[0], ctx);
    }

    mut loop2_res := typechecker.monomorphize(&env, "Loop2", loop_args, ctx);
    if loop2_res.tag == 0 { // Ok
        os.LogStr("Cycle Detection OK: Pointer-indirected Loop2 accepted");
    } else {
        os.LogStr("Cycle Detection FAIL: Pointer-indirected Loop2 rejected");
    }

    // 8. Test Dynamic Fallback Monomorphization for Nested Templates std.Graph[int, ctx] (Phase 2 Step 3 Fix)
    mut graph_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
    graph_args.Push(typechecker.make_type_int());
    graph_args.Push(typechecker.make_type_struct("ctx", "", ctx));

    mut graph_res := typechecker.monomorphize(&env, "std.Graph", graph_args, ctx);
    if graph_res.tag == 0 {
        mut concrete_t := graph_res.Ok.val;
        os.LogStr(std.Concat("Monomorphized Graph name: ", concrete_t.Struct.struct_name));

        mut layout_graph_lookup := env.struct_registry.Get(concrete_t.Struct.struct_name);
        if layout_graph_lookup.Ok {
            os.LogStr("std_Graph_int_ctx successfully registered!");
        } else {
            os.LogStr("std_Graph_int_ctx registration failed!");
        }

// Check if the nested std_GraphNode_int_ctx was dynamically monomorphized and registered!
            mut layout_node_lookup := env.struct_registry.Get("std_GraphNode_int_ctx");
            if layout_node_lookup.Ok {
                os.LogStr("std_GraphNode_int_ctx successfully registered dynamically!");
            } else {
                os.LogStr("std_GraphNode_int_ctx dynamic registration failed!");
            }
        } else {
            os.LogStr("Graph monomorphization failed!");
        }

        // 9. Test Function Parameter Registration in variable_types
        mut l_func: lexer.Lexer[ctx];
        lexer.init_lexer(&l_func, "func process(ctx: &Arena) {}");

        mut p_func: parser.Parser[ctx];
        parser.init_parser(&p_func, &l_func, ctx);

        mut prog_func := parser.parse_program(&p_func, ctx);
        if len(p_func.errors) > 0 {
            os.LogStr("ParserError in step 9");
            os.Exit(1);
        }

        mut scope_func := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
        unsafe {
            mut statements_vec := &ctx[prog_func.statements] as *std.Vector[ast.Statement[ctx], ctx];

            mut i := 0;
            while i < len(*statements_vec) {
                typechecker.env_pre_register_statement(&env, (*statements_vec)[i], ctx);
                i = i + 1;
            }

            mut j := 0;
            while j < len(*statements_vec) {
                mut stmt_idx: Index[ast.Statement[ctx], ctx] := os.ArenaAlloc(ctx);
                ctx[stmt_idx] = (*statements_vec)[j];
                typechecker.check_statement(stmt_idx, &env, scope_func, ctx);
                j = j + 1;
            }
        }

        mut lookup_param := env.variable_types.Get("ctx");
        if lookup_param.Ok {
            mut t_param := lookup_param.Val;
            if t_param.tag == 9 {
                unsafe {
                    mut inner_t := ctx[t_param.RawPointer.inner];
                    if inner_t.tag == 4 {
                        os.LogStr("Parameter ctx registered in variable_types correctly!");
                    } else {
                        os.LogStr("Parameter ctx registered in variable_types with incorrect inner type!");
                    }
                }
            } else {
                os.LogStr("Parameter ctx registered in variable_types with incorrect tag!");
            }
        } else {
            os.LogStr("Parameter ctx lookup in variable_types failed!");
        }
    }
