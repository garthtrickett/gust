import "phase20_exact_brand_boundary_import.gst" as model;

func main() {
    mut origin := os.Arena.New();
    defer origin.Free();
    mut destination := os.Arena.New();
    defer destination.Free();
    mut source: Index[model.ImportedNode, origin] := os.ArenaAlloc(origin);
    mut wrong: Index[model.ImportedNode, origin] := std.Clone(destination, source);
}
