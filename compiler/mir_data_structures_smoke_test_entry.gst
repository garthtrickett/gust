import "mir.gst" as mir;

func fail(msg: str) {
    os.LogStr(msg);
    os.Exit(1);
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span := mir.mir_make_empty_span();

    mut program := mir.mir_make_program(ctx);
    if len(ctx[program.functions]) != 0 {
        fail("MIR smoke: new program should start with zero functions");
    }

    mut function := mir.mir_make_function("mir_smoke", "int", span, ctx);
    if std.str_eq(function.name, "mir_smoke") == 0 {
        fail("MIR smoke: function name constructor field drifted");
    }
    if std.str_eq(function.return_type, "int") == 0 {
        fail("MIR smoke: function return_type constructor field drifted");
    }
    if function.entry_block != 0 {
        fail("MIR smoke: function entry_block should default to zero");
    }
    if len(ctx[function.params]) != 0 {
        fail("MIR smoke: new function should start with zero params");
    }
    if len(ctx[function.locals]) != 0 {
        fail("MIR smoke: new function should start with zero locals");
    }
    if len(ctx[function.blocks]) != 0 {
        fail("MIR smoke: new function should start with zero blocks");
    }

    mut local := mir.mir_make_local(0, "x", "int", span, ctx);
    if local.id != 0 {
        fail("MIR smoke: local id constructor field drifted");
    }
    if std.str_eq(local.name, "x") == 0 {
        fail("MIR smoke: local name constructor field drifted");
    }
    if std.str_eq(local.local_type, "int") == 0 {
        fail("MIR smoke: local type constructor field drifted");
    }

    mut local_read: mir.MirValue[ctx] := mir.mir_make_value_local_read(local.id, "int", span, ctx);
    if local_read.tag != 3 {
        fail("MIR smoke: local-read value tag drifted");
    }
    unsafe {
        if local_read.LocalRead.local_id != 0 {
            fail("MIR smoke: local-read local_id field drifted");
        }
        if std.str_eq(local_read.LocalRead.value_type, "int") == 0 {
            fail("MIR smoke: local-read value_type field drifted");
        }
    }

    mut local_read_idx := mir.mir_alloc_value(local_read, ctx);
    mut local_set: mir.MirStmt[ctx] := mir.mir_make_stmt_local_set(local.id, local_read_idx, span);
    if local_set.tag != 1 {
        fail("MIR smoke: local-set statement tag drifted");
    }
    unsafe {
        if local_set.LocalSet.local_id != 0 {
            fail("MIR smoke: local-set local_id field drifted");
        }
    }

    mut return_terminator: mir.MirTerminator[ctx] := mir.mir_make_terminator_return(local_read_idx, span);
    if return_terminator.tag != 1 {
        fail("MIR smoke: return terminator tag drifted");
    }

    mut jump_terminator: mir.MirTerminator[ctx] := mir.mir_make_terminator_jump(1, span, ctx);
    if jump_terminator.tag != 2 {
        fail("MIR smoke: jump terminator tag drifted");
    }
    unsafe {
        if jump_terminator.Jump.target_block != 1 {
            fail("MIR smoke: jump target_block field drifted");
        }
    }

    mut branch_terminator: mir.MirTerminator[ctx] := mir.mir_make_terminator_branch(local_read_idx, 1, 2, span);
    if branch_terminator.tag != 3 {
        fail("MIR smoke: branch terminator tag drifted");
    }
    unsafe {
        if branch_terminator.Branch.condition == empty[Index[mir.MirValue[ctx], ctx]] {
            fail("MIR smoke: branch condition field should be allocated");
        }
        if branch_terminator.Branch.then_block != 1 {
            fail("MIR smoke: branch then_block field drifted");
        }
        if branch_terminator.Branch.else_block != 2 {
            fail("MIR smoke: branch else_block field drifted");
        }
    }

    mut return_terminator_idx := mir.mir_alloc_terminator(return_terminator, ctx);
    mut block := mir.mir_make_block(0, return_terminator_idx, span, ctx);
    if block.id != 0 {
        fail("MIR smoke: block id constructor field drifted");
    }
    if len(ctx[block.statements]) != 0 {
        fail("MIR smoke: new block should start with zero statements");
    }
    if block.terminator == empty[Index[mir.MirTerminator[ctx], ctx]] {
        fail("MIR smoke: block terminator should be allocated");
    }

    os.LogStr("SUCCESS: mir data structures smoke");
}
