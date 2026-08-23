// Phase 20.0 baseline for CR-12/#159.
// current_result: rejects_distinct_destination_brand_at_generic_type_boundary
// fixed_by: 20.3

type Node[ctx] struct { value: int }

func main() {
    mut origin := os.Arena.New();
    defer origin.Free();
    mut destination := os.Arena.New();
    defer destination.Free();
    mut source: Index[Node, origin] := os.ArenaAlloc(origin);
    mut wrong: Index[Node, origin] := std.Clone(destination, source);
}
