// Phase 20.0 baseline for CR-13/#160.
// current_result: rejects_clone_through_freed_arena_receiver
// fixed_by: 20.5

func main() {
    mut destination := os.Arena.New();
    destination.Free();
    mut copied := std.Clone(destination, "freed");
}
