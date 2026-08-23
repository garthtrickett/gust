// Stdlib S1.4 inferred half. The explicit half differs only by local type
// annotations; both must produce byte-identical MIR-to-C output and behaviour.
type S1BrandedItem struct {
    value: int
}

type S1BrandedBundle[ctx] struct {
    values: std.Vector[int, ctx],
    lookup: std.HashMap[str, int, ctx],
    pool: std.Pool[S1BrandedItem, ctx],
    graph: std.Graph[S1BrandedItem, ctx],
    mutex: std.Mutex[int, ctx],
    channel: std.Channel[int, ctx],
    bytes: []byte
}

func make_vector(ctx: &Arena) std.Vector[int, ctx] {
    mut result: std.Vector[int, ctx] := std.VectorNew(ctx);
    result.Push(3);
    result.Push(5);
    return result;
}

func make_map(ctx: &Arena) std.HashMap[str, int, ctx] {
    mut result: std.HashMap[str, int, ctx] := std.HashMapNew(ctx);
    result.Insert("alpha", 7);
    return result;
}

func make_pool(ctx: &Arena) std.Pool[S1BrandedItem, ctx] {
    mut result: std.Pool[S1BrandedItem, ctx] := std.PoolNew(ctx);
    mut item: S1BrandedItem;
    item.value = 11;
    result.Alloc(item);
    return result;
}

func make_graph(ctx: &Arena) std.Graph[S1BrandedItem, ctx] {
    mut result: std.Graph[S1BrandedItem, ctx] := std.GraphNew(ctx);
    mut item: S1BrandedItem;
    item.value = 13;
    result.AddNode(item);
    return result;
}

func make_channel(ctx: &Arena) std.Channel[int, ctx] {
    return std.ChannelNew(ctx);
}

func make_mutex(ctx: &Arena) std.Mutex[int, ctx] {
    return std.MutexNew(ctx);
}

func make_nested(ctx: &Arena) std.Vector[std.Vector[int, ctx], ctx] {
    mut result: std.Vector[std.Vector[int, ctx], ctx] := std.VectorNew(ctx);
    result.Push(make_vector(ctx));
    return result;
}

func vector_size(values: &std.Vector[int, ctx]) int {
    return len(values);
}

func add_vector_value(values: &std.Vector[int, ctx], value: int) {
    values.Push(value);
}

func main() int {
    mut application_arena := os.Arena.New();
    defer application_arena.Free();

    mut vector_value := make_vector(&application_arena);
    readonly_vector := make_vector(&application_arena);
    mut map_value := make_map(&application_arena);
    mut pool_value := make_pool(&application_arena);
    mut graph_value := make_graph(&application_arena);
    mut mutex_value := make_mutex(&application_arena);
    mut channel_value := make_channel(&application_arena);
    mut nested_value := make_nested(&application_arena);
    mut keys_value := map_value.Keys(&application_arena);

    mut empty_bundle: S1BrandedBundle[application_arena];
    bytes_value := empty_bundle.bytes;

    add_vector_value(&vector_value, 17);
    mutex_value.value = 19;
    mut total := vector_size(&vector_value);
    total = total + vector_size(&readonly_vector);
    total = total + len(map_value);
    total = total + pool_value.len;
    total = total + graph_value.nodes.len;
    total = total + mutex_value.value;
    total = total + channel_value.len;
    total = total + len(nested_value);
    total = total + len(keys_value);
    total = total + len(bytes_value);
    if total != 29 { return 1; }
    return 64;
}
