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

func check_one_move_call_boundary(ctx: &Arena) {
    unsafe {
    mut env := typechecker.env_new(ctx);
    mut stmt := parse_statement("unsafe func make_zero() *int { return empty[*int]; }", ctx);
    typechecker.env_pre_register_statement(&env, ctx[stmt], ctx);
    mut target := typechecker.make_type_pointer(typechecker.make_type_int(), ctx);
    mut moved := parse_expression("move make_zero()", ctx);
    mut moved_expr := ctx[moved];
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, moved, moved_expr.Move.span, "function argument", ctx
    );
    if len(env.pending_zero_direct_calls) != 1 {
        os.LogStr("Error: one Move(Call) boundary lost its direct summary"); os.Exit(1);
    }
    if typechecker.phase26_zero_direct_nullary_callee(&env, moved, ctx) != empty[Index[str, ctx]] {
        os.LogStr("Error: Move(Call) changed direct local-candidate selection"); os.Exit(1);
    }
    mut inner_call_idx := moved_expr.Move.expr;
    mut inner_call := ctx[inner_call_idx];
    mut wrapped_callee: ast.Expression[ctx];
    wrapped_callee.tag = 9; // AsCast is not a direct Identifier callee.
    wrapped_callee.AsCast.left = inner_call.Call.function;
    wrapped_callee.AsCast.span = inner_call.Call.span;
    mut wrapped_callee_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(wrapped_callee_idx, wrapped_callee);
    inner_call.Call.function = wrapped_callee_idx;
    ctx.Set(inner_call_idx, inner_call);
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, moved, moved_expr.Move.span, "function argument", ctx
    );
    mut nested := parse_expression("move move make_zero()", ctx);
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, nested, moved_expr.Move.span, "function argument", ctx
    );
    mut taken := parse_expression("take make_zero()", ctx);
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, taken, moved_expr.Move.span, "function argument", ctx
    );
    mut generic_lookup := env.function_registry.Get("make_zero");
    if generic_lookup.Ok {
        mut generic_sig := generic_lookup.Val;
        mut generic_args: std.Vector[ast.Type[ctx], ctx] := std.VectorNew(ctx);
        generic_sig.return_type = typechecker.make_type_pointer(
            typechecker.make_type_generic("T", generic_args, ctx), ctx
        );
        env.function_registry.Insert("make_generic", generic_sig);
    } else {
        os.LogStr("Error: direct test signature missing"); os.Exit(1);
    }
    mut generic_call := parse_expression("move make_generic()", ctx);
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, generic_call, moved_expr.Move.span, "function argument", ctx
    );
    if len(env.pending_zero_direct_calls) != 1 {
        os.LogStr("Error: wrapped callee, nested Move, Take, or generic Call acquired a direct summary"); os.Exit(1);
    }
    }
}

func check_one_local_direct_call_shape(ctx: &Arena) {
    unsafe {
    mut env := typechecker.env_new(ctx);
    mut declaration := parse_statement("unsafe func make_zero() *int { return empty[*int]; }", ctx);
    typechecker.env_pre_register_statement(&env, ctx[declaration], ctx);
    mut direct := parse_expression("make_zero()", ctx);
    mut callee := typechecker.phase26_zero_direct_nullary_callee(&env, direct, ctx);
    if callee == empty[Index[str, ctx]] || std.str_eq(ctx[callee], "make_zero") == 0 {
        os.LogStr("Error: concrete nullary direct call was not selected for one local"); os.Exit(1);
    }
    env.zero_local_call_name = "ptr";
    mut consume := parse_statement("accept_raw(ptr);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[consume], &env, ctx) != 1 {
        os.LogStr("Error: one-local direct argument was not selected"); os.Exit(1);
    }
    mut overwrite := parse_statement("ptr = 1 as *int;", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[overwrite], &env, ctx) != 0 {
        os.LogStr("Error: intervening assignment retained one-local candidate"); os.Exit(1);
    }
    mut alias := parse_statement("mut alias := ptr;", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[alias], &env, ctx) != 0 {
        os.LogStr("Error: alias declaration retained one-local candidate"); os.Exit(1);
    }
    if std.str_eq(typechecker.phase26_zero_local_call_alias_name(ctx[alias], &env, ctx), "alias") == 0 {
        os.LogStr("Error: direct one-hop alias was not selected"); os.Exit(1);
    }
    mut take_alias := parse_statement("mut taken := take ptr;", ctx);
    if std.str_eq(typechecker.phase26_zero_local_call_alias_name(ctx[take_alias], &env, ctx), "taken") == 0 {
        os.LogStr("Error: one Take alias was not selected"); os.Exit(1);
    }
    env.zero_local_call_name = "taken";
    env.zero_local_call_take_alias_terminal = 1;
    mut after_take := parse_statement("mut after_take := taken;", ctx);
    if std.str_eq(typechecker.phase26_zero_local_call_alias_name(ctx[after_take], &env, ctx), "") == 0 {
        os.LogStr("Error: Take alias extended into another alias"); os.Exit(1);
    }
    env.zero_local_call_name = "ptr";
    env.zero_local_call_take_alias_terminal = 0;
    mut take_nested := parse_statement("mut taken_nested := take take ptr;", ctx);
    if std.str_eq(typechecker.phase26_zero_local_call_alias_name(ctx[take_nested], &env, ctx), "") == 0 {
        os.LogStr("Error: nested Take alias acquired a summary"); os.Exit(1);
    }
    mut move_alias := parse_statement("mut moved := move ptr;", ctx);
    if std.str_eq(typechecker.phase26_zero_local_call_alias_name(ctx[move_alias], &env, ctx), "") == 0 {
        os.LogStr("Error: Move alias acquired a Take summary"); os.Exit(1);
    }
    env.zero_local_call_name = "alias";
    env.zero_local_call_alias_hops = 1;
    mut next := parse_statement("mut next := alias;", ctx);
    if std.str_eq(typechecker.phase26_zero_local_call_alias_name(ctx[next], &env, ctx), "next") == 0 {
        os.LogStr("Error: consecutive alias chain lost its second hop"); os.Exit(1);
    }
    env.zero_local_call_name = "next";
    env.zero_local_call_alias_hops = 2;
    mut third := parse_statement("mut third := next;", ctx);
    if std.str_eq(typechecker.phase26_zero_local_call_alias_name(ctx[third], &env, ctx), "third") == 0 {
        os.LogStr("Error: consecutive alias chain lost its third hop"); os.Exit(1);
    }
    env.zero_local_call_name = "third";
    env.zero_local_call_alias_hops = 3;
    mut direct_call := parse_statement("accept_raw(third);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[direct_call], &env, ctx) != 1 {
        os.LogStr("Error: direct call did not consume the final alias"); os.Exit(1);
    }
    mut direct_call_expr := ctx[direct_call].Expression.expr;
    mut call := ctx[direct_call_expr];
    mut direct_callee := call.Call.function;
    mut indirect_callee: ast.Expression[ctx];
    indirect_callee.tag = 9; // AsCast, which is not a direct Identifier callee.
    indirect_callee.AsCast.left = direct_callee;
    indirect_callee.AsCast.span = call.Call.span;
    mut indirect_idx: Index[ast.Expression[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(indirect_idx, indirect_callee);
    call.Call.function = indirect_idx;
    ctx.Set(direct_call_expr, call);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[direct_call], &env, ctx) != 0 {
        os.LogStr("Error: wrapped callee consumed an alias-chain candidate"); os.Exit(1);
    }
    mut intervening := parse_statement("mut other := 1;", ctx);
    if std.str_eq(typechecker.phase26_zero_local_call_alias_name(ctx[intervening], &env, ctx), "") == 0 {
        os.LogStr("Error: unrelated declaration retained alias-chain candidate"); os.Exit(1);
    }
    env.zero_local_call_name = "ptr";
    env.zero_local_call_take_alias_terminal = 0;
    mut direct_take := parse_statement("accept_raw(take ptr);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[direct_take], &env, ctx) != 1 {
        os.LogStr("Error: direct terminal Take argument lost its candidate"); os.Exit(1);
    }
    env.zero_local_call_take_alias_terminal = 1;
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[direct_take], &env, ctx) != 0 {
        os.LogStr("Error: Take alias acquired a second Take hop"); os.Exit(1);
    }
    env.zero_local_call_take_alias_terminal = 0;
    mut nested_take := parse_statement("accept_raw(take take ptr);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[nested_take], &env, ctx) != 0 {
        os.LogStr("Error: nested Take argument acquired a summary"); os.Exit(1);
    }
    mut other_take := parse_statement("accept_raw(take other);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[other_take], &env, ctx) != 0 {
        os.LogStr("Error: unrelated Take argument acquired a summary"); os.Exit(1);
    }
    mut direct_move := parse_statement("accept_raw(move ptr);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[direct_move], &env, ctx) != 1 {
        os.LogStr("Error: direct terminal Move argument lost its candidate"); os.Exit(1);
    }
    env.zero_local_call_take_alias_terminal = 1;
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[direct_move], &env, ctx) != 0 {
        os.LogStr("Error: terminal Take alias acquired a Move hop"); os.Exit(1);
    }
    env.zero_local_call_take_alias_terminal = 0;
    mut move_call_expr := ctx[direct_move].Expression.expr;
    mut move_call := ctx[move_call_expr];
    move_call.Call.function = indirect_idx;
    ctx.Set(move_call_expr, move_call);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[direct_move], &env, ctx) != 0 {
        os.LogStr("Error: wrapped callee consumed a Move candidate"); os.Exit(1);
    }
    mut nested_move := parse_statement("accept_raw(move move ptr);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[nested_move], &env, ctx) != 0 {
        os.LogStr("Error: nested Move argument acquired a summary"); os.Exit(1);
    }
    mut other_move := parse_statement("accept_raw(move other);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[other_move], &env, ctx) != 0 {
        os.LogStr("Error: unrelated Move argument acquired a summary"); os.Exit(1);
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
    check_one_move_call_boundary(ctx);
    check_one_local_direct_call_shape(ctx);
    os.LogStr("SUCCESS: checked direct-return zero summaries and excluded parameters and wrapped callees verified");
}
