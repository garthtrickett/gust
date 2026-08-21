// Phase 19.1 rename-invariance baseline, arm B.
//
// The arena parameter is spelled `scratch`, which does NOT appear in the hardcoded brand
// vocabulary at src/codegen.rs:71 and compiler/codegen.gst:658. Brand erasure
// therefore strips the suffix and the emitted struct is named `Holder`.
//
// Arm A is this file with the parameter spelled `ctx`.
// Under D-1 the two arms would emit the same C. They do not: see
// compiler/CRANELIFT_PHASE19_SPELLING_INVENTORY.md.
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
