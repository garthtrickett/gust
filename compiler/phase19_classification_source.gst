func classify_with_scratch(scratch: &Arena) int {
    mut values: std.Vector[int, scratch] := std.VectorNew(scratch);
    values.Push(11);

    mut mapping: std.HashMap[int, int, scratch] := std.HashMapNew(scratch);
    mapping.Insert(2, 13);

    mut pool: std.Pool[int, scratch] := std.PoolNew(scratch);
    mut pool_index := pool.Alloc(17);

    mut arena_index: Index[int, scratch] := os.ArenaAlloc(scratch);
    scratch.Set(arena_index, 19);

    if values[0] != 11 { return 1; }
    if mapping[2] != 13 { return 2; }
    if pool[pool_index] != 17 { return 3; }
    if scratch[arena_index] != 19 { return 4; }
    if "ok"[1] != 107 { return 5; }
    return 0;
}

func main() int {
    mut storage := os.Arena.New();
    defer storage.Free();
    return classify_with_scratch(&storage);
}
