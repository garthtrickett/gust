// Phase 19.1 rename-invariance baseline, arm A.
//
// The arena parameter is spelled `ctx`, which the remaining self-hosted
// classification path recognizes. Patch 19.3 constructs the emitted struct
// name as `Holder` from its brand identity metadata.
//
// Arm B is this file with the parameter renamed and nothing else changed.
// Patch 19.3 keeps this arm internally consistent as Holder. The paired
// scratch arm is now also internally consistent, but still names its type
// Holder_scratch; later Phase 19 convergence patches own that remaining D-1
// difference.
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
