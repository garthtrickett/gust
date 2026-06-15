import "ast.gst" as ast;
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
}
