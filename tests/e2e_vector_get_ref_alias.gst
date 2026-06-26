func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut vec_alias: std.Vector[int, ctx] := std.VectorNew(ctx);
    vec_alias.Push(11);
    vec_alias.Push(22);

    mut alias_ref := std.VectorGetRef(vec_alias, 1);
    os.LogInt(*alias_ref);

    *alias_ref = 44;
    os.LogInt(vec_alias[1]);
}