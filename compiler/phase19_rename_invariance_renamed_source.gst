// Phase 19.1 rename-invariance baseline, arm B.
//
// The arena parameter is spelled `scratch`, which does NOT appear in the hardcoded brand
// vocabulary formerly used by compiler/codegen.gst. Patch 19.3 constructs a
// consistent `Holder_scratch` declaration and allocation without suffix
// surgery, so this arm now compiles.
//
// Arm A is this file with the parameter spelled `ctx`.
// Under D-1 the two arms would emit the same normalized C. They still do not;
// later Phase 19 type-derived classification and convergence patches own the
// remaining rename difference.
type Holder[scratch] struct {
    values: std.Vector[int, scratch]
}

func holder_make(scratch: &Arena) Index[Holder[scratch], scratch] {
    mut values: std.Vector[int, scratch] := std.VectorNew(scratch);
    values.Push(7);
    mut holder: Holder[scratch];
    holder.values = values;
    mut holder_index: Index[Holder[scratch], scratch] := os.ArenaAlloc(scratch);
    scratch.Set(holder_index, holder);
    return holder_index;
}

func main() int {
    return 7;
}
