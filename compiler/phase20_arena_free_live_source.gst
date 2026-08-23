// Patch 20.5 accepted control: both arenas remain independently live until
// their deferred scope-exit Free operations.
func main() int {
    mut primary := os.Arena.New();
    defer primary.Free();
    mut secondary := os.Arena.New();
    defer secondary.Free();

    mut primary_index: Index[int, primary] := os.ArenaAlloc(primary);
    primary.Set(primary_index, 37);
    mut copied := std.Clone(primary, "live");

    mut secondary_index: Index[int, secondary] := os.ArenaAlloc(secondary);
    secondary.Set(secondary_index, 11);
    return 37;
}
