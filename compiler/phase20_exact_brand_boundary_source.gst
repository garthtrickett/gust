// Patch 20.3 positive: an exact same-arena identity survives Clone,
// annotation, assignment, argument, return, field, and import-alias boundaries.
import "phase20_exact_brand_boundary_import.gst" as model;

type Phase20ExactNode[ctx] struct { value: int }
type Phase20ExactHolder[ctx] struct { node: Index[Phase20ExactNode, ctx] }

func accept_exact(first: Index[Phase20ExactNode, ctx], second: Index[Phase20ExactNode, ctx]) Index[Phase20ExactNode, ctx] {
    return second;
}

func same_brand_probe(ctx: &Arena) Index[Phase20ExactNode, ctx] {
    mut source: Index[Phase20ExactNode, ctx] := os.ArenaAlloc(ctx);
    mut annotated: Index[Phase20ExactNode, ctx] := std.Clone(ctx, source);
    mut assigned: Index[Phase20ExactNode, ctx] := source;
    assigned = std.Clone(ctx, source);
    mut called := accept_exact(source, assigned);
    mut holder: Phase20ExactHolder[ctx];
    holder.node = called;
    mut imported: Index[model.ImportedNode, ctx] := os.ArenaAlloc(ctx);
    return holder.node;
}

func main() int {
    return 23;
}
