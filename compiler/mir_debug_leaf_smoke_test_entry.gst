import "mir.gst" as mir;

func fail(msg: str) {
    os.LogStr(msg);
    os.Exit(1);
}

func expect_str_eq(actual: str, expected: str, label: str) {
    if std.str_eq(actual, expected) == 0 {
        os.LogStr(label);
        os.LogStr("expected:");
        os.LogStr(expected);
        os.LogStr("actual:");
        os.LogStr(actual);
        os.Exit(1);
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span := mir.mir_make_empty_span();

    mut int_value: mir.MirValue[ctx] := mir.mir_make_value_int_literal(7, "int", span, ctx);
    expect_str_eq(mir.mir_debug_value_kind(int_value), "MirValue.IntLiteral", "MIR leaf debug: int literal kind drifted");

    mut bool_value: mir.MirValue[ctx] := mir.mir_make_value_bool_literal(1, "bool", span, ctx);
    expect_str_eq(mir.mir_debug_value_kind(bool_value), "MirValue.BoolLiteral", "MIR leaf debug: bool literal kind drifted");

    mut string_value: mir.MirValue[ctx] := mir.mir_make_value_string_literal("hello", "str", span, ctx);
    expect_str_eq(mir.mir_debug_value_kind(string_value), "MirValue.StringLiteral", "MIR leaf debug: string literal kind drifted");

    mut local_read: mir.MirValue[ctx] := mir.mir_make_value_local_read(0, "int", span, ctx);
    expect_str_eq(mir.mir_debug_value_kind(local_read), "MirValue.LocalRead", "MIR leaf debug: local read kind drifted");

    mut args := mir.mir_empty_value_vector(ctx);
    mut call_value: mir.MirValue[ctx] := mir.mir_make_value_call("callee", args, "int", span);
    expect_str_eq(mir.mir_debug_value_kind(call_value), "MirValue.Call", "MIR leaf debug: call kind drifted");

    mut local_read_idx := mir.mir_alloc_value(local_read, ctx);

    mut nop_stmt: mir.MirStmt[ctx] := mir.mir_make_stmt_nop(span, ctx);
    expect_str_eq(mir.mir_debug_stmt_kind(nop_stmt), "MirStmt.Nop", "MIR leaf debug: nop statement kind drifted");

    mut local_set_stmt: mir.MirStmt[ctx] := mir.mir_make_stmt_local_set(0, local_read_idx, span);
    expect_str_eq(mir.mir_debug_stmt_kind(local_set_stmt), "MirStmt.LocalSet", "MIR leaf debug: local-set statement kind drifted");

    mut expr_stmt: mir.MirStmt[ctx] := mir.mir_make_stmt_expr(local_read_idx, span);
    expect_str_eq(mir.mir_debug_stmt_kind(expr_stmt), "MirStmt.Expr", "MIR leaf debug: expr statement kind drifted");

    mut return_void: mir.MirTerminator[ctx] := mir.mir_make_terminator_return_void(span, ctx);
    expect_str_eq(mir.mir_debug_terminator_kind(return_void), "MirTerminator.ReturnVoid", "MIR leaf debug: return-void terminator kind drifted");

    mut return_term: mir.MirTerminator[ctx] := mir.mir_make_terminator_return(local_read_idx, span);
    expect_str_eq(mir.mir_debug_terminator_kind(return_term), "MirTerminator.Return", "MIR leaf debug: return terminator kind drifted");

    mut jump_term: mir.MirTerminator[ctx] := mir.mir_make_terminator_jump(1, span, ctx);
    expect_str_eq(mir.mir_debug_terminator_kind(jump_term), "MirTerminator.Jump", "MIR leaf debug: jump terminator kind drifted");

    mut branch_term: mir.MirTerminator[ctx] := mir.mir_make_terminator_branch(local_read_idx, 1, 2, span);
    expect_str_eq(mir.mir_debug_terminator_kind(branch_term), "MirTerminator.Branch", "MIR leaf debug: branch terminator kind drifted");

    os.LogStr("SUCCESS: mir debug leaf smoke");
}