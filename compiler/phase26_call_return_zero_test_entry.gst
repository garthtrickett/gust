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

func parse_expression(src: str, ctx: &Arena) Index[ast.Expression[ctx], ctx] {
    mut lex: lexer.Lexer[ctx];
    lexer.init_lexer(&lex, src);
    mut p: parser.Parser[ctx];
    parser.init_parser(&p, &lex, ctx);
    return parser.parse_expression(&p, 1, ctx);
}

func check_wrapped_callees_excluded(ctx: &Arena) {
    unsafe {
    mut env := typechecker.env_new(ctx);
    mut stmt := parse_statement("unsafe func make_zero() *int { return empty[*int]; }", ctx);
    typechecker.env_pre_register_statement(&env, ctx[stmt], ctx);
    mut target := typechecker.make_type_pointer(typechecker.make_type_int(), ctx);
    mut expr_idx := parse_expression("make_zero()", ctx);
    mut call := ctx[expr_idx];
    mut direct := call.Call.function;
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, expr_idx, call.Call.span, "function argument", ctx
    );
    if len(env.pending_zero_direct_calls) != 1 {
        os.LogStr("Error: direct Identifier call was not recorded"); os.Exit(1);
    }

    mut wrapped: ast.Expression[ctx];
    wrapped.tag = 9; // AsCast, whose string rendering discards the cast.
    wrapped.AsCast.left = direct;
    wrapped.AsCast.span = call.Call.span;
    mut wrapped_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(wrapped_idx, wrapped);
    call.Call.function = wrapped_idx;
    ctx.Set(expr_idx, call);
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, expr_idx, call.Call.span, "function argument", ctx
    );
    if len(env.pending_zero_direct_calls) != 1 {
        os.LogStr("Error: cast-wrapped callee acquired direct summary"); os.Exit(1);
    }
    wrapped.tag = 4; // Move
    wrapped.Move.expr = direct;
    wrapped.Move.span = call.Call.span;
    ctx.Set(wrapped_idx, wrapped);
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, expr_idx, call.Call.span, "function argument", ctx
    );
    if len(env.pending_zero_direct_calls) != 1 {
        os.LogStr("Error: move-wrapped callee acquired direct summary"); os.Exit(1);
    }
    wrapped.tag = 5; // Take
    wrapped.Take.expr = direct;
    wrapped.Take.span = call.Call.span;
    ctx.Set(wrapped_idx, wrapped);
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, expr_idx, call.Call.span, "function argument", ctx
    );
    if len(env.pending_zero_direct_calls) != 1 {
        os.LogStr("Error: take-wrapped callee acquired direct summary"); os.Exit(1);
    }
    }
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
    check_wrapped_callees_excluded(ctx);
    os.LogStr("SUCCESS: checked direct-return zero summaries and excluded parameters and wrapped callees verified");
}
