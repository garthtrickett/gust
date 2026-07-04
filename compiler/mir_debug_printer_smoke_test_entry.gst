import "mir.gst" as mir;

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut span := mir.mir_make_empty_span();

    mut program := mir.mir_make_program(ctx);
    mir.mir_debug_print_program(program);

    mut function := mir.mir_make_function("mir_smoke", "int", span, ctx);
    mir.mir_debug_print_function(function);

    mut local_read: mir.MirValue[ctx] := mir.mir_make_value_local_read(0, "int", span, ctx);
    mir.mir_debug_print_value(local_read);

    mut local_read_idx := mir.mir_alloc_value(local_read, ctx);
    mut local_set: mir.MirStmt[ctx] := mir.mir_make_stmt_local_set(0, local_read_idx, span);
    mir.mir_debug_print_stmt(local_set);

    mut return_terminator: mir.MirTerminator[ctx] := mir.mir_make_terminator_return(local_read_idx, span);
    mir.mir_debug_print_terminator(return_terminator);

    mut return_terminator_idx := mir.mir_alloc_terminator(return_terminator, ctx);
    mut block := mir.mir_make_block(0, return_terminator_idx, span, ctx);
    mir.mir_debug_print_block(block, ctx);

    os.LogStr("SUCCESS: mir debug printer smoke");
}