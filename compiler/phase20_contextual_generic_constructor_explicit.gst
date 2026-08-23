// Patch 20.3a explicit half. The inferred half omits only local annotations;
// both must emit byte-identical MIR-to-C.

func make_contextual_channel(ctx: &Arena) std.Channel[int, ctx] {
    return std.ChannelNew(ctx);
}

func make_contextual_vector(ctx: &Arena) std.Vector[int, ctx] {
    return std.VectorNew(ctx);
}

func consume_contextual_vector(values: std.Vector[int, ctx]) int {
    return len(values);
}

func contextual_argument_probe(ctx: &Arena) int {
    return consume_contextual_vector(std.VectorNew(ctx));
}

func main() int {
    mut application_arena := os.Arena.New();
    defer application_arena.Free();

    mut annotated: std.Vector[int, application_arena] := std.VectorNew(&application_arena);
    mut assigned: std.Vector[int, application_arena] := std.VectorNew(&application_arena);
    assigned = std.VectorNew(&application_arena);
    mut inferred_channel: std.Channel[int, application_arena] := make_contextual_channel(&application_arena);
    mut inferred_vector: std.Vector[int, application_arena] := make_contextual_vector(&application_arena);

    if len(annotated) != 0 { return 1; }
    if len(assigned) != 0 { return 2; }
    if inferred_channel.len != 0 { return 3; }
    if len(inferred_vector) != 0 { return 4; }
    if contextual_argument_probe(&application_arena) != 0 { return 5; }
    return 31;
}
