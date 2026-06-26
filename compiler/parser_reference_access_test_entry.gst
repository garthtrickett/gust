import "token.gst" as token;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "ast.gst" as ast;

func test_ctx_access(ctx: &Arena) {
    mut l_ctx: lexer.Lexer[ctx];
    lexer.init_lexer(&l_ctx, "ctx.get_ref(idx)");

    mut p_ctx: parser.Parser[ctx];
    parser.init_parser(&p_ctx, &l_ctx, ctx);

    mut expr_ctx := parser.parse_expression(&p_ctx, 1, ctx);

    unsafe {
        if expr_ctx == empty[Index[ast.Expression[ctx], ctx]] {
            os.LogStr("Error: parsed expression is empty");
            os.Exit(1);
        }

        mut expr := ctx[expr_ctx];
        if expr.tag != 12 { // Call = 12
            os.LogStr("Error: expected Call (tag 12)");
            os.Exit(1);
        }

        mut func_expr_idx := expr.Call.function;
        mut func_expr := ctx[func_expr_idx];
        if func_expr.tag != 11 { // Selector = 11
            os.LogStr("Error: expected Selector (tag 11) for function");
            os.Exit(1);
        }

        mut left_expr_idx := func_expr.Selector.left;
        mut left_expr := ctx[left_expr_idx];
        if left_expr.tag != 0 { // Identifier = 0
            os.LogStr("Error: expected Identifier (tag 0) for selector left");
            os.Exit(1);
        }

        if std.str_eq(left_expr.Identifier.name, "ctx") == 0 {
            os.LogStr("Error: expected selector left to be 'ctx'");
            os.Exit(1);
        }

        if std.str_eq(func_expr.Selector.right, "get_ref") == 0 {
            os.LogStr("Error: expected selector right to be 'get_ref'");
            os.Exit(1);
        }

        mut args_vec: std.Vector[ast.Expression[ctx], ctx] := ctx[expr.Call.arguments];
        if len(args_vec) != 1 {
            os.LogStr("Error: expected exactly 1 argument");
            os.Exit(1);
        }

        mut arg_expr := args_vec[0];
        if arg_expr.tag != 0 { // Identifier = 0
            os.LogStr("Error: expected argument to be Identifier (tag 0)");
            os.Exit(1);
        }

        if std.str_eq(arg_expr.Identifier.name, "idx") == 0 {
            os.LogStr("Error: expected argument to be 'idx'");
            os.Exit(1);
        }
    }
}

func test_vec_access(ctx: &Arena) {
    mut l_vec: lexer.Lexer[ctx];
    lexer.init_lexer(&l_vec, "vec.GetRef(idx)");

    mut p_vec: parser.Parser[ctx];
    parser.init_parser(&p_vec, &l_vec, ctx);

    mut expr_vec := parser.parse_expression(&p_vec, 1, ctx);

    unsafe {
        if expr_vec == empty[Index[ast.Expression[ctx], ctx]] {
            os.LogStr("Error: parsed expression is empty");
            os.Exit(1);
        }

        mut expr := ctx[expr_vec];
        if expr.tag != 12 { // Call = 12
            os.LogStr("Error: expected Call (tag 12)");
            os.Exit(1);
        }

        mut func_expr_idx := expr.Call.function;
        mut func_expr := ctx[func_expr_idx];
        if func_expr.tag != 11 { // Selector = 11
            os.LogStr("Error: expected Selector (tag 11) for function");
            os.Exit(1);
        }

        mut left_expr_idx := func_expr.Selector.left;
        mut left_expr := ctx[left_expr_idx];
        if left_expr.tag != 0 { // Identifier = 0
            os.LogStr("Error: expected Identifier (tag 0) for selector left");
            os.Exit(1);
        }

        if std.str_eq(left_expr.Identifier.name, "vec") == 0 {
            os.LogStr("Error: expected selector left to be 'vec'");
            os.Exit(1);
        }

        if std.str_eq(func_expr.Selector.right, "GetRef") == 0 {
            os.LogStr("Error: expected selector right to be 'GetRef'");
            os.Exit(1);
        }

        mut args_vec: std.Vector[ast.Expression[ctx], ctx] := ctx[expr.Call.arguments];
        if len(args_vec) != 1 {
            os.LogStr("Error: expected exactly 1 argument");
            os.Exit(1);
        }

        mut arg_expr := args_vec[0];
        if arg_expr.tag != 0 { // Identifier = 0
            os.LogStr("Error: expected argument to be Identifier (tag 0)");
            os.Exit(1);
        }

        if std.str_eq(arg_expr.Identifier.name, "idx") == 0 {
            os.LogStr("Error: expected argument to be 'idx'");
            os.Exit(1);
        }
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    test_ctx_access(ctx);
    test_vec_access(ctx);

    os.LogStr("SUCCESS: Explicit reference-access method call parsing verified!");
}
