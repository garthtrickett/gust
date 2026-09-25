// Native direct-call reference parameters must keep the caller's aggregate
// address for field writes, collection methods, len, and vector indexing.
type ReferenceReceiverBox[ctx] struct { n: int }

func bump_box(box: &ReferenceReceiverBox[ctx]) {
    (*box).n = (*box).n + 11;
}

func push_vector(values: &std.Vector[int, ctx]) {
    values.Push(5);
}

func vector_first(values: &std.Vector[int, ctx]) int {
    return values[0];
}

func vector_size(values: &std.Vector[int, ctx]) int {
    return len(values);
}

func main() {
    mut arena := os.Arena.New();
    defer arena.Free();

    mut box: ReferenceReceiverBox[arena];
    box.n = 0;
    bump_box(&box);
    os.LogInt(box.n);

    mut values: std.Vector[int, arena] := std.VectorNew(arena);
    values.Push(7);
    push_vector(&values);
    os.LogInt(vector_size(&values));
    os.LogInt(vector_first(&values));
    os.LogInt(values[1]);
    os.LogStr("SUCCESS: native reference receivers");
}
