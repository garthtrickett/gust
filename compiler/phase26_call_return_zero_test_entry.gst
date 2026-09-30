import "ast.gst" as ast;
import "lexer.gst" as lexer;
import "parser.gst" as parser;
import "typechecker.gst" as typechecker;

func parse_statement(src: str, ctx: &Arena) Index[ast.Statement[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_statement(&p, ctx);
}

func check_summary(src: str, name: str, expected: int, present: int, ctx: &Arena) {
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut stmt := parse_statement(src, ctx);
    typechecker.env_pre_register_statement(&env, ctx[stmt], ctx);
    typechecker.check_statement(stmt, &env, scope, ctx);
    if len(env.errors) != 0 {
        os.LogStr("Error: direct-return summary function did not typecheck");
        os.LogStr(src);
        os.LogStr(env.errors[0].message);
        os.Exit(1);
    }
    mut found := env.function_return_zero_states.Get(name);
    if present == 0 {
        if found.Ok { os.LogStr("Error: excluded function acquired zero summary"); os.Exit(1); }
    } else {
        if found.Ok == false { os.LogStr("Error: direct return has no zero summary"); os.Exit(1); }
        if found.Ok {
            if found.Val != expected {
                os.LogStr("Error: direct return zero summary drifted");
                os.LogInt(found.Val);
                os.Exit(1);
            }
        }
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    check_summary("unsafe func make_zero() *int { return empty[*int]; }",
                  "make_zero", typechecker.phase26_zero_yes(), 1, ctx);
    check_summary("unsafe func make_computed_zero() *int { return (0 + 0) as *int; }",
                  "make_computed_zero", typechecker.phase26_zero_yes(), 1, ctx);
    check_summary("unsafe func make_mayzero() *int { return (256 as byte) as *int; }",
                  "make_mayzero", typechecker.phase26_zero_may(), 1, ctx);
    check_summary("unsafe func make_nonzero() *int { return 1 as *int; }",
                  "make_nonzero", typechecker.phase26_zero_no(), 1, ctx);
    check_summary("unsafe func pass_raw(ptr: *int) *int { return ptr; }",
                  "pass_raw", typechecker.phase26_zero_unknown(), 0, ctx);
    os.LogStr("SUCCESS: checked direct-return zero summaries and excluded parameters verified");
}
