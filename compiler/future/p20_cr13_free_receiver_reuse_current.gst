// Phase 20.0 baseline for CR-13/#160.
// current_result: incorrectly_accepts_clone_through_freed_arena_receiver
// next_patch: 20.5

func main() {
    mut destination := os.Arena.New();
    destination.Free();
    mut copied := std.Clone(destination, "freed");
}
