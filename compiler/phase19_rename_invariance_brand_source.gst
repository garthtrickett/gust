// Phase 19.1 rename-invariance baseline, arm A.
//
// The arena parameter is spelled `ctx`. The final type-derived authority must
// not incorporate that spelling into the emitted `Holder` type identity.
//
// Arm B is this file with the parameter renamed and nothing else changed.
// Both arms must emit byte-identical C after normalizing the deliberately
// renamed source local.
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
