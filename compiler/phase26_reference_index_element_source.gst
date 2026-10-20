func read_byte(ctx: &Arena, values: &std.Vector[byte, ctx]) int {
    mut observed: byte := values[1];
    if observed == 7 { return 1; }
    return 0;
}

func read_int(ctx: &Arena, values: &std.Vector[int, ctx]) int {
    return values[1];
}

func read_bool(ctx: &Arena, values: &std.Vector[bool, ctx]) int {
    mut observed: bool := values[1];
    if observed == true { return 1; }
    return 0;
}

func main() int {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut bytes: std.Vector[byte, ctx] := std.VectorNew(&ctx);
    mut ints: std.Vector[int, ctx] := std.VectorNew(&ctx);
    mut bools: std.Vector[bool, ctx] := std.VectorNew(&ctx);
    mut b: byte := 7;
    mut first_byte: byte := 3;
    bytes.Push(first_byte);
    bytes.Push(b);
    ints.Push(9);
    ints.Push(41);
    bools.Push(false);
    bools.Push(true);
    if read_byte(&ctx, &bytes) != 1 { return 1; }
    if read_int(&ctx, &ints) != 41 { return 2; }
    if read_bool(&ctx, &bools) != 1 { return 3; }
    if bytes[1] != b { return 4; }
    return 0;
}
