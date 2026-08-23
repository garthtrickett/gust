// Phase 20.2 resolved probe for CR-11/#158.
// current_result: accepts_explicit_graph_annotation_with_resolved_nested_brand_identity
// fixed_by: 20.2

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
