import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut lex_canonical_defer: lexer.Lexer[ctx];
    lexer.init_lexer(&lex_canonical_defer, "defer close_resource(resource);");

    mut parser_canonical_defer: parser.Parser[ctx];
    parser.init_parser(&parser_canonical_defer, &lex_canonical_defer, ctx);

    mut stmt_canonical_defer := parser.parse_statement(&parser_canonical_defer, ctx);

    unsafe {
        if ctx[stmt_canonical_defer].tag != 11 { // Defer = 11
            os.LogStr("Error: canonical Resource cleanup form must parse as a Defer statement");
            os.Exit(1);
        }

        mut defer_expr_idx_canonical := ctx[stmt_canonical_defer].Defer.expr;
        if ctx[defer_expr_idx_canonical].tag != 12 { // Call = 12
            os.LogStr("Error: canonical Resource cleanup defer must wrap a call expression");
            os.Exit(1);
        }

        mut defer_callee_idx_canonical := ctx[defer_expr_idx_canonical].Call.function;
        if ctx[defer_callee_idx_canonical].tag != 0 { // Identifier = 0
            os.LogStr("Error: canonical Resource cleanup defer callee must be a plain destructor identifier");
            os.Exit(1);
        }
        if std.str_eq(ctx[defer_callee_idx_canonical].Identifier.name, "close_resource") == 0 {
            os.LogStr("Error: canonical Resource cleanup defer must preserve destructor identifier name");
            os.Exit(1);
        }

        mut defer_args_canonical: std.Vector[ast.Expression[ctx], ctx] := ctx[ctx[defer_expr_idx_canonical].Call.arguments];
        if len(defer_args_canonical) != 1 {
            os.LogStr("Error: canonical Resource cleanup defer must have exactly one argument");
            os.Exit(1);
        }

        mut defer_arg_idx_canonical: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
        ctx.Set(defer_arg_idx_canonical, defer_args_canonical[0]);
        if ctx[defer_arg_idx_canonical].tag != 0 { // Identifier = 0
            os.LogStr("Error: canonical Resource cleanup defer first argument must be a tracked Resource identifier surface");
            os.Exit(1);
        }
        if std.str_eq(ctx[defer_arg_idx_canonical].Identifier.name, "resource") == 0 {
            os.LogStr("Error: canonical Resource cleanup defer must preserve first Resource argument name");
            os.Exit(1);
        }
    }

    os.LogStr("SUCCESS: canonical Resource defer syntax surface verified!");
}