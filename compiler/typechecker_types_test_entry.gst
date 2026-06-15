import "ast.gst" as ast;
import "typechecker.gst" as typechecker;
import "lexer.gst" as lexer;
import "parser.gst" as parser;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

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

    // Verify lookup of variables and enums inside registries
    mut lookup_var := env.variable_types.Get("x");
    if lookup_var.Ok {
        os.LogStr(std.Concat("variable_types lookup ok, type tag: ", std.FormatInt(lookup_var.Val.tag)));
    } else {
        os.LogStr("variable_types lookup failed");
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
}
