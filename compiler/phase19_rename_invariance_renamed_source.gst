// Phase 19.1 rename-invariance baseline, arm B.
//
// The arena parameter is spelled `scratch`, which did not appear in the
// hardcoded brand vocabulary formerly used by compiler/codegen.gst. The final
// type-derived authority must not incorporate that spelling into the emitted
// `Holder` type identity.
//
// Arm A is this file with the parameter spelled `ctx`.
// Both arms must emit byte-identical C after normalizing the deliberately
// renamed source local.
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
