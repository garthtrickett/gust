// Phase 20.0 baseline for CR-11/#158.
// current_result: rejects_valid_program_with_three_brand_nesting_restrictions_and_secondary_void_mismatch
// next_patch: 20.2

type S1GraphNode struct { value: int }

func make_graph(ctx: &Arena) std.Graph[S1GraphNode, ctx] {
    mut graph: std.Graph[S1GraphNode, ctx] := std.GraphNew(ctx);
    return graph;
}

func main() {
    mut application_arena := os.Arena.New();
    defer application_arena.Free();
    mut graph: std.Graph[S1GraphNode, application_arena] := make_graph(&application_arena);
}
