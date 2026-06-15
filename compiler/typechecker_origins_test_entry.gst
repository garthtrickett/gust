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
    mut brand_idx := os.ArenaAlloc(ctx) as Index[str, ctx];
    unsafe {
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
}
