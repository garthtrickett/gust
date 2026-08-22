// Phase 20.0 baseline for CR-12/#159.
// current_result: incorrectly_accepts_distinct_destination_brand
// next_patch: 20.3

type Node[ctx] struct { value: int }

func main() {
    mut origin := os.Arena.New();
    defer origin.Free();
    mut destination := os.Arena.New();
    defer destination.Free();
    mut source: Index[Node, origin] := os.ArenaAlloc(origin);
    mut wrong: Index[Node, origin] := std.Clone(destination, source);
}
