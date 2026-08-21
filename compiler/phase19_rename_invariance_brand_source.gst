// Phase 19.1 rename-invariance baseline, arm A.
//
// The arena parameter is spelled `ctx`, which appears in the hardcoded brand
// vocabulary at src/codegen.rs:71 and compiler/codegen.gst:658. Brand erasure
// therefore strips the suffix and the emitted struct is named `Holder`.
//
// Arm B is this file with the parameter renamed and nothing else changed.
// Under D-1 the two arms would emit the same C. They do not: see
// compiler/CRANELIFT_PHASE19_SPELLING_INVENTORY.md.
type Holder[ctx] struct {
    values: std.Vector[int, ctx]
}

func holder_make(ctx: &Arena) Index[Holder[ctx], ctx] {
    mut values: std.Vector[int, ctx] := std.VectorNew(ctx);
    values.Push(7);
    mut holder: Holder[ctx];
    holder.values = values;
    mut holder_index: Index[Holder[ctx], ctx] := os.ArenaAlloc(ctx);
    ctx.Set(holder_index, holder);
    return holder_index;
}

func main() int {
    return 7;
}
