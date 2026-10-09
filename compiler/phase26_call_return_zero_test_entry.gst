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
    if len(env.pending_zero_direct_calls) != 2 {
        os.LogStr("Error: two Move wrappers lost their direct summary"); os.Exit(1);
    }
    if typechecker.phase26_zero_direct_nullary_callee(&env, nested, ctx) != empty[Index[str, ctx]] {
        os.LogStr("Error: two Move wrappers changed direct local-candidate selection"); os.Exit(1);
    }
    mut three_wrappers := parse_expression("move move move make_zero()", ctx);
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, three_wrappers, moved_expr.Move.span, "function argument", ctx
    );
    if len(env.pending_zero_direct_calls) != 3 {
        os.LogStr("Error: three Move wrappers lost their direct summary"); os.Exit(1);
    }
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
    if len(env.pending_zero_direct_calls) != 3 {
        os.LogStr("Error: wrapped callee or generic Call acquired a direct summary"); os.Exit(1);
    }
    }
}

func check_one_take_call_boundary(ctx: &Arena) {
    unsafe {
    mut env := typechecker.env_new(ctx);
    mut stmt := parse_statement("unsafe func make_zero() *int { return empty[*int]; }", ctx);
    typechecker.env_pre_register_statement(&env, ctx[stmt], ctx);
    mut target := typechecker.make_type_pointer(typechecker.make_type_int(), ctx);
    mut taken := parse_expression("take make_zero()", ctx);
    mut taken_expr := ctx[taken];
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, taken, taken_expr.Take.span, "function argument", ctx
    );
    if len(env.pending_zero_direct_calls) != 1 {
        os.LogStr("Error: one Take(Call) boundary lost its direct summary"); os.Exit(1);
    }
    if typechecker.phase26_zero_direct_nullary_callee(&env, taken, ctx) != empty[Index[str, ctx]] {
        os.LogStr("Error: Take(Call) changed direct local-candidate selection"); os.Exit(1);
    }
    mut nested := parse_expression("take take make_zero()", ctx);
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, nested, taken_expr.Take.span, "function argument", ctx
    );
    mut moved_taken := parse_expression("move take make_zero()", ctx);
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, moved_taken, taken_expr.Take.span, "function argument", ctx
    );
    mut taken_moved := parse_expression("take move make_zero()", ctx);
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, taken_moved, taken_expr.Take.span, "function argument", ctx
    );
    mut moved_moved := parse_expression("move move make_zero()", ctx);
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, moved_moved, taken_expr.Take.span, "function argument", ctx
    );
    if len(env.pending_zero_direct_calls) != 5 {
        os.LogStr("Error: depth-two Move/Take boundary lost a direct summary"); os.Exit(1);
    }
    if typechecker.phase26_zero_direct_nullary_callee(&env, nested, ctx) != empty[Index[str, ctx]] {
        os.LogStr("Error: depth-two Take changed direct local-candidate selection"); os.Exit(1);
    }
    mut three_wrappers := parse_expression("take move take make_zero()", ctx);
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, three_wrappers, taken_expr.Take.span, "function argument", ctx
    );
    if len(env.pending_zero_direct_calls) != 6 {
        os.LogStr("Error: three mixed wrappers lost their direct summary"); os.Exit(1);
    }
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
    mut generic_call := parse_expression("take make_generic()", ctx);
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, generic_call, taken_expr.Take.span, "function argument", ctx
    );
    mut inner_call_idx := taken_expr.Take.expr;
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
        &env, target, taken, taken_expr.Take.span, "function argument", ctx
    );
    if len(env.pending_zero_direct_calls) != 6 {
        os.LogStr("Error: generic or indirect Call acquired a direct summary"); os.Exit(1);
    }
    }
}

func check_wrapper_chain_boundary(ctx: &Arena) {
    unsafe {
    mut env := typechecker.env_new(ctx);
    mut stmt := parse_statement("unsafe func make_zero() *int { return empty[*int]; }", ctx);
    typechecker.env_pre_register_statement(&env, ctx[stmt], ctx);
    mut target := typechecker.make_type_pointer(typechecker.make_type_int(), ctx);
    mut cases: std.Vector[str, ctx] := std.VectorNew(ctx);
    cases.Push("move move move make_zero()");
    cases.Push("move move take make_zero()");
    cases.Push("move take move make_zero()");
    cases.Push("move take take make_zero()");
    cases.Push("take move move make_zero()");
    cases.Push("take move take make_zero()");
    cases.Push("take take move make_zero()");
    cases.Push("take take take make_zero()");
    cases.Push("move take move take make_zero()");
    mut i := 0;
    while i < len(cases) {
        mut expr_idx := parse_expression(cases[i], ctx);
        typechecker.phase26_zero_note_direct_call_boundary(
            &env, target, expr_idx, ctx[stmt].FunctionDecl.span, "function argument", ctx
        );
        if len(env.pending_zero_direct_calls) != i + 1 {
            os.LogStr("Error: checked Move/Take wrapper chain lost direct summary"); os.Exit(1);
        }
        if typechecker.phase26_zero_direct_nullary_callee(&env, expr_idx, ctx) != empty[Index[str, ctx]] {
            os.LogStr("Error: wrapper chain changed local direct-candidate selection"); os.Exit(1);
        }
        i = i + 1;
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
    mut direct_return := parse_statement("return ptr;", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[direct_return], &env, ctx) != 1 {
        os.LogStr("Error: immediate direct local return lost its candidate window"); os.Exit(1);
    }
    mut cast_return := parse_statement("return ptr as *int;", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_return], &env, ctx) != 0 {
        os.LogStr("Error: direct-local cast return widened the plain-alias candidate window"); os.Exit(1);
    }
    mut cast_chain_return := parse_statement("return (ptr as *int) as *int;", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_chain_return], &env, ctx) != 0 {
        os.LogStr("Error: direct-local cast-chain return widened the plain-alias candidate window"); os.Exit(1);
    }
    env.zero_local_call_alias_hops = 1;
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[direct_return], &env, ctx) != 1 {
        os.LogStr("Error: plain alias local return lost its candidate window"); os.Exit(1);
    }
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_return], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_chain_return], &env, ctx) != 1 {
        os.LogStr("Error: plain-alias checked cast return lost its candidate window"); os.Exit(1);
    }
    env.zero_local_call_alias_hops = 3;
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[direct_return], &env, ctx) != 1 {
        os.LogStr("Error: consecutive plain alias return lost its candidate window"); os.Exit(1);
    }
    env.zero_local_call_take_alias_terminal = 1;
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[direct_return], &env, ctx) != 1 {
        os.LogStr("Error: validated Take alias lost the plain-return candidate window"); os.Exit(1);
    }
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_return], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_chain_return], &env, ctx) != 1 {
        os.LogStr("Error: validated Take alias lost the checked cast-return candidate window"); os.Exit(1);
    }
    mut direct_take_return := parse_statement("return take ptr;", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[direct_take_return], &env, ctx) != 1 {
        os.LogStr("Error: one Take lost the alias-return candidate window"); os.Exit(1);
    }
    mut take_cast_return := parse_statement("return take ((ptr as *int) as *int);", ctx);
    mut cast_take_return := parse_statement("return ((take ptr) as *int) as *int;", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[take_cast_return], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_take_return], &env, ctx) != 1 {
        os.LogStr("Error: one Take with checked cast chain lost the alias-return candidate window"); os.Exit(1);
    }
    mut nested_take_return := parse_statement("return take (take ptr);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[nested_take_return], &env, ctx) != 1 {
        os.LogStr("Error: two Takes lost the alias-return candidate window"); os.Exit(1);
    }
    mut third_take_return := parse_statement("return take (take (take ptr));", ctx);
    mut fourth_take_return := parse_statement("return take (take (take (take ptr)));", ctx);
    mut third_take_outer_cast := parse_statement("return (take (take (take ptr))) as *int;", ctx);
    mut third_take_inner_cast := parse_statement("return take (take (take (ptr as *int)));", ctx);
    mut fourth_take_interleaved_cast := parse_statement("return take ((take ((take ((take ptr) as *int)) as *int)) as *int);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[third_take_return], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[fourth_take_return], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[third_take_outer_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[third_take_inner_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[fourth_take_interleaved_cast], &env, ctx) != 1 {
        os.LogStr("Error: finite Take-only return chain lost its candidate window"); os.Exit(1);
    }
    mut moved_two_take_return := parse_statement("return move (take (take ptr));", ctx);
    mut moved_two_take_outer_cast := parse_statement("return move (((take (take ptr)) as *int) as *int);", ctx);
    mut moved_two_take_inner_cast := parse_statement("return move (take (take ((ptr as *int) as *int)));", ctx);
    mut moved_two_take_interleaved_cast := parse_statement("return move (take (((take ptr) as *int) as *int));", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_two_take_return], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_two_take_outer_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_two_take_inner_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_two_take_interleaved_cast], &env, ctx) != 1 {
        os.LogStr("Error: outer Move over two Takes lost its bounded return window"); os.Exit(1);
    }
    mut moved_third_take_return := parse_statement("return move (take (take (take ptr)));", ctx);
    mut moved_fourth_take_return := parse_statement("return move (take (take (take (take ptr))));", ctx);
    mut moved_third_take_outer_cast := parse_statement("return move (((take (take (take ptr))) as *int) as *int);", ctx);
    mut moved_third_take_inner_cast := parse_statement("return move (take (take (take (ptr as *int))));", ctx);
    mut moved_fourth_take_interleaved_cast := parse_statement("return move (take ((take ((take ((take ptr) as *int)) as *int)) as *int));", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_third_take_return], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_fourth_take_return], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_third_take_outer_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_third_take_inner_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_fourth_take_interleaved_cast], &env, ctx) != 1 {
        os.LogStr("Error: outer Move over finite Takes lost its candidate window"); os.Exit(1);
    }
    mut inner_moved_two_take_return := parse_statement("return take (move (take ptr));", ctx);
    mut inner_moved_two_take_outer_cast := parse_statement("return (take (move (take ptr))) as *int;", ctx);
    mut inner_moved_two_take_middle_cast := parse_statement("return take ((move (take ptr)) as *int);", ctx);
    mut inner_moved_two_take_inner_cast := parse_statement("return take (move (take (ptr as *int)));", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_moved_two_take_return], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_moved_two_take_outer_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_moved_two_take_middle_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_moved_two_take_inner_cast], &env, ctx) != 1 {
        os.LogStr("Error: one inner Move between two Takes lost its bounded return window"); os.Exit(1);
    }
    mut third_take_before_move := parse_statement("return take (take (take (move ptr)));", ctx);
    mut third_take_before_move_cast := parse_statement("return take (take ((take (move ptr)) as *int));", ctx);
    mut third_take_before_move_outer_cast := parse_statement("return (take (take (take (move (ptr as *int))))) as *int;", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[third_take_before_move], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[third_take_before_move_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[third_take_before_move_outer_cast], &env, ctx) != 1 {
        os.LogStr("Error: innermost Move beneath exactly three Takes lost its bounded return window"); os.Exit(1);
    }
    mut fourth_take_before_move := parse_statement("return take (take (take (take (move ptr))));", ctx);
    mut inner_move_return := parse_statement("return move (take (move (take ptr)));", ctx);
    mut second_move_return := parse_statement("return move (move (take (take ptr)));", ctx);
    mut cast_outside_move_return := parse_statement("return (move (take (take ptr))) as *int;", ctx);
    mut inner_move_under_both_takes := parse_statement("return take (take (move ptr));", ctx);
    mut inner_move_under_both_outer_cast := parse_statement("return (take (take (move ptr))) as *int;", ctx);
    mut inner_move_under_both_between_takes_cast := parse_statement("return take (((take (move ptr)) as *int));", ctx);
    mut inner_move_under_both_before_move_cast := parse_statement("return take (take (((move ptr) as *int)));", ctx);
    mut inner_move_under_both_inside_move_cast := parse_statement("return take (take (move (ptr as *int)));", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_move_under_both_takes], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_move_under_both_outer_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_move_under_both_between_takes_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_move_under_both_before_move_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_move_under_both_inside_move_cast], &env, ctx) != 1 {
        os.LogStr("Error: innermost Move beneath two Takes lost its bounded return window"); os.Exit(1);
    }
    mut inner_move_one_take := parse_statement("return take (move ptr);", ctx);
    mut inner_move_third_take := parse_statement("return take (move (take (take ptr)));", ctx);
    mut outer_move_second_move_after_third_take := parse_statement("return move (take (take (take (move ptr))));", ctx);
    mut outer_cast_after_move_third_take := parse_statement("return (move (take (take (take ptr)))) as *int;", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[fourth_take_before_move], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[outer_move_second_move_after_third_take], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[outer_cast_after_move_third_take], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_move_return], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[second_move_return], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_outside_move_return], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_move_one_take], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_move_third_take], &env, ctx) != 0 {
        os.LogStr("Error: Move-bearing third Take, nested Move or cast outside Move widened the return window"); os.Exit(1);
    }
    mut moved_return := parse_statement("return move ptr;", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_return], &env, ctx) != 0 {
        os.LogStr("Error: Move widened the alias-return candidate window"); os.Exit(1);
    }
    env.zero_local_call_alias_hops = 0;
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[direct_take_return], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_two_take_return], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_third_take_return], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_moved_two_take_return], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_move_under_both_takes], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[third_take_before_move], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[take_cast_return], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_two_take_outer_cast], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_third_take_outer_cast], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_moved_two_take_outer_cast], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[inner_move_under_both_outer_cast], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[third_take_before_move_outer_cast], &env, ctx) != 0 {
        os.LogStr("Error: checked Move and Take alias prerequisite drifted"); os.Exit(1);
    }
    env.zero_local_call_take_alias_terminal = 0;
    env.zero_local_call_alias_hops = 0;
    mut consume := parse_statement("accept_raw(ptr);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[consume], &env, ctx) != 1 {
        os.LogStr("Error: one-local direct argument was not selected"); os.Exit(1);
    }
    mut cast_call := parse_statement("accept_raw(ptr as *int);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_call], &env, ctx) != 1 {
        os.LogStr("Error: one checked cast lost the direct local candidate window"); os.Exit(1);
    }
    mut nested_cast_call := parse_statement("accept_raw((ptr as *int) as *int);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[nested_cast_call], &env, ctx) != 1 {
        os.LogStr("Error: checked nested local cast lost the candidate window"); os.Exit(1);
    }
    mut nested_stmt := ctx[nested_cast_call];
    mut nested_call := ctx[nested_stmt.Expression.expr];
    mut nested_args: std.Vector[ast.Expression[ctx], ctx] := ctx[nested_call.Call.arguments];
    if typechecker.phase26_zero_local_call_argument_cast_is_raw(nested_args[0], &env, ctx) != 0 {
        os.LogStr("Error: unchecked nested cast acquired a raw-pointer summary"); os.Exit(1);
    }
    mut triple_cast_call := parse_statement("accept_raw(((ptr as *int) as *int) as *int);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[triple_cast_call], &env, ctx) != 1 {
        os.LogStr("Error: checked triple local cast lost the candidate window"); os.Exit(1);
    }
    mut moved_cast_call := parse_statement("accept_raw((move ptr) as *int);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_cast_call], &env, ctx) != 0 {
        os.LogStr("Error: moved local cast acquired a candidate window"); os.Exit(1);
    }
    mut cast_take_call := parse_statement("accept_raw((take ptr) as *int);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_take_call], &env, ctx) != 1 {
        os.LogStr("Error: checked cast around Take lost the local candidate window"); os.Exit(1);
    }
    mut take_cast_call := parse_statement("accept_raw(take (ptr as *int));", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[take_cast_call], &env, ctx) != 1 {
        os.LogStr("Error: Take around checked cast lost the local candidate window"); os.Exit(1);
    }
    mut take_cast_stmt := ctx[take_cast_call];
    mut take_cast_expr := ctx[take_cast_stmt.Expression.expr];
    mut take_cast_args: std.Vector[ast.Expression[ctx], ctx] := ctx[take_cast_expr.Call.arguments];
    if typechecker.phase26_zero_local_call_argument_cast_is_raw(take_cast_args[0], &env, ctx) != 0 {
        os.LogStr("Error: unchecked Take-wrapped cast acquired raw-pointer proof"); os.Exit(1);
    }
    mut nested_take_cast := parse_statement("accept_raw(take ((ptr as *int) as *int));", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[nested_take_cast], &env, ctx) != 1 {
        os.LogStr("Error: checked cast chain inside Take lost the local candidate window"); os.Exit(1);
    }
    mut cast_nested_take := parse_statement("accept_raw(((take ptr) as *int) as *int);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_nested_take], &env, ctx) != 1 {
        os.LogStr("Error: checked cast chain outside Take lost the local candidate window"); os.Exit(1);
    }
    mut triple_take_cast := parse_statement("accept_raw(take (((ptr as *int) as *int) as *int));", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[triple_take_cast], &env, ctx) != 1 {
        os.LogStr("Error: three checked casts inside Take lost the local candidate window"); os.Exit(1);
    }
    mut cast_triple_take := parse_statement("accept_raw((((take ptr) as *int) as *int) as *int);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_triple_take], &env, ctx) != 1 {
        os.LogStr("Error: three checked casts outside Take lost the local candidate window"); os.Exit(1);
    }
    mut double_take_cast := parse_statement("accept_raw(take take (ptr as *int));", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[double_take_cast], &env, ctx) != 0 {
        os.LogStr("Error: second Take widened the local candidate window"); os.Exit(1);
    }
    mut triple_outer_take_cast := parse_statement("accept_raw(take take take ((ptr as *int) as *int));", ctx);
    mut double_outer_take_plain := parse_statement("accept_raw(take take ptr);", ctx);
    mut triple_outer_take_plain := parse_statement("accept_raw(take take take ptr);", ctx);
    mut interleaved_take_cast := parse_statement("accept_raw(take ((take (ptr as *int)) as *int));", ctx);
    mut deep_interleaved_take_cast := parse_statement("accept_raw(take ((take ((take (ptr as *int)) as *int)) as *int));", ctx);
    mut cast_outer_interleaved_take := parse_statement("accept_raw((take ((take (ptr as *int)) as *int)) as *int);", ctx);
    mut cast_outer_consecutive_take := parse_statement("accept_raw((take take ptr) as *int);", ctx);
    mut moved_cast_argument := parse_statement("accept_raw(move (ptr as *int));", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_cast_argument], &env, ctx) != 1 {
        os.LogStr("Error: Move-wrapped checked cast lost the local candidate window"); os.Exit(1);
    }
    mut moved_cast_chain := parse_statement("accept_raw(move (((ptr as *int) as *int) as *int));", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_cast_chain], &env, ctx) != 1 {
        os.LogStr("Error: Move-wrapped checked cast chain lost the local candidate window"); os.Exit(1);
    }
    mut moved_chain_stmt := ctx[moved_cast_chain];
    mut moved_chain_call := ctx[moved_chain_stmt.Expression.expr];
    mut moved_chain_args: std.Vector[ast.Expression[ctx], ctx] := ctx[moved_chain_call.Call.arguments];
    if typechecker.phase26_zero_local_call_argument_cast_is_raw(moved_chain_args[0], &env, ctx) != 0 {
        os.LogStr("Error: unchecked Move-wrapped cast acquired raw-pointer proof"); os.Exit(1);
    }
    mut second_move_cast := parse_statement("accept_raw(move move (ptr as *int));", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[second_move_cast], &env, ctx) != 0 {
        os.LogStr("Error: second Move widened the local candidate window"); os.Exit(1);
    }
    mut move_take_cast := parse_statement("accept_raw(move take (ptr as *int));", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[move_take_cast], &env, ctx) != 0 {
        os.LogStr("Error: Move/Take combination widened the local candidate window"); os.Exit(1);
    }
    env.zero_local_call_alias_hops = 1;
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_call], &env, ctx) != 1 {
        os.LogStr("Error: one plain alias lost its single checked cast candidate window"); os.Exit(1);
    }
    env.zero_local_call_name = "alias";
    mut alias_cast_call := parse_statement("accept_raw(alias as *int);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[alias_cast_call], &env, ctx) != 1 {
        os.LogStr("Error: named plain alias lost its single checked cast candidate window"); os.Exit(1);
    }
    mut alias_cast_chain_call := parse_statement("accept_raw(((alias as *int) as *int) as *int);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[alias_cast_chain_call], &env, ctx) != 1 {
        os.LogStr("Error: named plain alias lost its checked cast-chain candidate window"); os.Exit(1);
    }
    env.zero_local_call_alias_hops = 2;
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[alias_cast_call], &env, ctx) != 1 {
        os.LogStr("Error: second plain alias lost its checked cast candidate window"); os.Exit(1);
    }
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[alias_cast_chain_call], &env, ctx) != 1 {
        os.LogStr("Error: second plain alias lost its checked cast-chain candidate window"); os.Exit(1);
    }
    env.zero_local_call_alias_hops = 3;
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[alias_cast_chain_call], &env, ctx) != 1 {
        os.LogStr("Error: third plain alias lost its checked cast-chain candidate window"); os.Exit(1);
    }
    env.zero_local_call_take_alias_terminal = 1;
    env.zero_local_call_alias_hops = 1;
    mut terminal_take_call := parse_statement("accept_raw(take alias);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[terminal_take_call], &env, ctx) != 1 {
        os.LogStr("Error: terminal Take of named alias lost its candidate"); os.Exit(1);
    }
    mut terminal_move_call := parse_statement("accept_raw(move alias);", ctx);
    mut terminal_nested_take_call := parse_statement("accept_raw(take take alias);", ctx);
    mut terminal_take_cast_call := parse_statement("accept_raw((take alias) as *int);", ctx);
    mut terminal_cast_chain_take_call := parse_statement("accept_raw(take ((ptr as *int) as *int));", ctx);
    mut terminal_wrong_name_call := parse_statement("accept_raw(take ptr);", ctx);
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[terminal_move_call], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[terminal_wrong_name_call], &env, ctx) != 0 {
        os.LogStr("Error: excluded terminal wrapper acquired an alias candidate"); os.Exit(1);
    }
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[terminal_nested_take_call], &env, ctx) != 1 {
        os.LogStr("Error: consecutive outer Take lost terminal alias candidate"); os.Exit(1);
    }
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[terminal_take_cast_call], &env, ctx) != 1 {
        os.LogStr("Error: checked outer cast lost terminal Take alias candidate"); os.Exit(1);
    }
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[alias_cast_call], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[alias_cast_chain_call], &env, ctx) != 1 {
        os.LogStr("Error: one Take-terminal alias lost its checked cast candidate window"); os.Exit(1);
    }
    env.zero_local_call_alias_hops = 2;
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[alias_cast_call], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[alias_cast_chain_call], &env, ctx) != 1 {
        os.LogStr("Error: one plain alias before Take lost its checked cast candidate window"); os.Exit(1);
    }
    env.zero_local_call_alias_hops = 3;
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[alias_cast_call], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[alias_cast_chain_call], &env, ctx) != 1 {
        os.LogStr("Error: consecutive plain aliases before Take lost the checked cast candidate window"); os.Exit(1);
    }
    env.zero_local_call_alias_hops = 4;
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[alias_cast_chain_call], &env, ctx) != 1 {
        os.LogStr("Error: finite plain aliases before Take lost the checked cast-chain candidate window"); os.Exit(1);
    }
    env.zero_local_call_take_alias_terminal = 0;
    env.zero_local_call_name = "ptr";
    env.zero_local_call_alias_hops = 1;
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_take_call], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[take_cast_call], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[nested_take_cast], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_nested_take], &env, ctx) != 0 {
        os.LogStr("Error: alias hop widened the Take/cast local candidate window"); os.Exit(1);
    }
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[nested_cast_call], &env, ctx) != 1 {
        os.LogStr("Error: alias nested-cast lost the checked candidate window"); os.Exit(1);
    }
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_cast_chain], &env, ctx) != 0 {
        os.LogStr("Error: alias widened the Move/cast local candidate window"); os.Exit(1);
    }
    env.zero_local_call_alias_hops = 0;
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
    if std.str_eq(typechecker.phase26_zero_local_call_alias_name(ctx[after_take], &env, ctx), "after_take") == 0 {
        os.LogStr("Error: plain suffix after Take lost its candidate"); os.Exit(1);
    }
    mut second_take := parse_statement("mut second_take := take taken;", ctx);
    if std.str_eq(typechecker.phase26_zero_local_call_alias_name(ctx[second_take], &env, ctx), "second_take") == 0 {
        os.LogStr("Error: second Take alias lost the checked local candidate"); os.Exit(1);
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
    env.zero_local_call_alias_hops = 0; // A terminal marker alone cannot authorize a second Take.
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_take_call], &env, ctx) != 0 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[take_cast_call], &env, ctx) != 0 {
        os.LogStr("Error: terminal Take alias acquired a second Take/cast hop"); os.Exit(1);
    }
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[direct_take], &env, ctx) != 0 {
        os.LogStr("Error: Take alias acquired a second Take hop"); os.Exit(1);
    }
    env.zero_local_call_alias_hops = 2;
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_take_call], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_nested_take], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_triple_take], &env, ctx) != 1 {
        os.LogStr("Error: terminal Take alias lost checked outer cast chain"); os.Exit(1);
    }
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[take_cast_call], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[terminal_cast_chain_take_call], &env, ctx) != 1 {
        os.LogStr("Error: terminal Take alias lost checked inner cast chain"); os.Exit(1);
    }
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[double_take_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[triple_outer_take_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[double_outer_take_plain], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[triple_outer_take_plain], &env, ctx) != 1 {
        os.LogStr("Error: terminal Take alias lost consecutive outer Take chain"); os.Exit(1);
    }
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[interleaved_take_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[deep_interleaved_take_cast], &env, ctx) != 1 ||
       typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_outer_interleaved_take], &env, ctx) != 1 {
        os.LogStr("Error: terminal Take alias lost an interleaved checked cast chain"); os.Exit(1);
    }
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[moved_cast_call], &env, ctx) != 0 {
        os.LogStr("Error: terminal Take alias admitted outer Move"); os.Exit(1);
    }
    if typechecker.phase26_zero_local_call_statement_consumes_candidate(ctx[cast_outer_consecutive_take], &env, ctx) != 0 {
        os.LogStr("Error: terminal Take alias admitted cast over repeated Take without interleaving"); os.Exit(1);
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

func check_pointer_cast_chain_boundary(src: str, target: ast.Type[ctx], checked: int, expected: int, ctx: &Arena) {
    mut env := typechecker.env_new(ctx);
    mut scope := typechecker.scope_new(empty[Index[typechecker.Scope[ctx], ctx]], ctx);
    mut stmt := parse_statement("unsafe func make_zero() *int { return empty[*int]; }", ctx);
    typechecker.env_pre_register_statement(&env, ctx[stmt], ctx);
    env.in_unsafe_block = 1;
    mut expr_idx := parse_expression(src, ctx);
    if checked == 1 {
        typechecker.check_expression(expr_idx, &env, scope, ctx);
        if len(env.errors) != 0 {
            os.LogStr("Error: pointer cast boundary control did not typecheck");
            os.LogStr(src);
            os.LogStr(env.errors[0].message);
            os.Exit(1);
        }
    }
    mut span := typechecker.get_expression_span(expr_idx, ctx);
    typechecker.phase26_zero_note_direct_call_boundary(
        &env, target, expr_idx, span, "function argument", ctx
    );
    if len(env.pending_zero_direct_calls) != expected {
        os.LogStr("Error: checked RawPointer AsCast or mixed Move/Take boundary selection drifted");
        os.LogStr(src);
        os.LogInt(len(env.pending_zero_direct_calls));
        os.Exit(1);
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
    check_one_take_call_boundary(ctx);
    check_wrapper_chain_boundary(ctx);
    check_one_local_direct_call_shape(ctx);
    mut int_pointer := typechecker.make_type_pointer(typechecker.make_type_int(), ctx);
    mut byte_pointer := typechecker.make_type_pointer(typechecker.make_type_byte(), ctx);
    check_pointer_cast_chain_boundary("make_zero() as *int", int_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("make_zero() as *byte", byte_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("make_zero() as *int", int_pointer, 0, 0, ctx);
    check_pointer_cast_chain_boundary("(make_zero() as *int) as *int", int_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("((make_zero() as *int) as *byte) as *int", int_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("((make_zero() as *int) as *byte) as *int", int_pointer, 0, 0, ctx);
    check_pointer_cast_chain_boundary("move (make_zero() as *int)", int_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("(move make_zero()) as *int", int_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("take (make_zero() as *int)", int_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("(take make_zero()) as *int", int_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("move (make_zero() as *int)", int_pointer, 0, 0, ctx);
    check_pointer_cast_chain_boundary("(take make_zero()) as *int", int_pointer, 0, 0, ctx);
    check_pointer_cast_chain_boundary("move ((make_zero() as *int) as *int)", int_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("((move make_zero()) as *int) as *int", int_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("move take (make_zero() as *int)", int_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("(move take make_zero()) as *int", int_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("move ((take make_zero() as *int) as *int)", int_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("(take (move (make_zero() as *int))) as *int", int_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("take (move (take (make_zero() as *int))) as *int", int_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("move ((take make_zero() as *int) as *byte)", byte_pointer, 1, 1, ctx);
    check_pointer_cast_chain_boundary("move ((take make_zero() as *int) as *int)", int_pointer, 0, 0, ctx);
    check_pointer_cast_chain_boundary("move ((make_zero() as int) as *int)", int_pointer, 1, 0, ctx);
    check_pointer_cast_chain_boundary("0 as *int", int_pointer, 1, 0, ctx);
    os.LogStr("SUCCESS: checked direct-return zero summaries, RawPointer AsCast chains, mixed Move/Take cast chains, consecutive outer Take chains, interleaved Take/cast chains, local safe returns and plain-alias safe returns and Take-alias safe returns, and exclusions verified");
}
