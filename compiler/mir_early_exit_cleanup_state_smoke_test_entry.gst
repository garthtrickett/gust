import "mir_early_exit_cleanup.gst" as early;

func main() {
    mut ctx: Arena;
    if early.mir_early_exit_cleanup_exit_kind_selected("direct_return") == 0 ||
       early.mir_early_exit_cleanup_exit_kind_selected("nested_conditional_return") == 0 ||
       early.mir_early_exit_cleanup_exit_kind_selected("selected_loop_return") == 0 ||
       early.mir_early_exit_cleanup_exit_kind_selected("selected_break") == 0 ||
       early.mir_early_exit_cleanup_exit_kind_selected("selected_continue") == 0 ||
       early.mir_early_exit_cleanup_exit_kind_selected("goto") != 0
    {
        os.Exit(1);
    }
    os.LogStr("SUCCESS: Phase 15.6 early-return cleanup state policy passed");
}