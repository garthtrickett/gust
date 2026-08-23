// Patch 20.2 CR-11 positive: explicit and inferred nested declarations must
// resolve the same arena identity through local, field, and import aliases.
import "phase20_nested_brand_annotation_import.gst" as model;

type Phase20GraphNode struct { value: int }
type Phase20ArenaHolder struct { arena: Arena }

func local_annotation_probe(application_arena: &Arena) {
    mut explicit: std.Graph[Phase20GraphNode, application_arena] := std.GraphNew(application_arena);
    mut inferred := move explicit;

    mut imported_explicit: std.Graph[model.ImportedGraphNode, application_arena] := std.GraphNew(application_arena);

    mut two_levels: std.Pool[std.GraphNode[Phase20GraphNode, application_arena], application_arena] := std.PoolNew(application_arena);
}

func field_annotation_probe(holder: &Phase20ArenaHolder) {
    mut field_explicit: std.Graph[Phase20GraphNode, holder.arena];
}

func main() int {
    return 20;
}
