func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut nums: std.Vector[int, ctx] := std.VectorNew(ctx);
    nums.Push(1);

    // Step 4.5C: safe vector slot writes must use vec.Set.
    nums[0] = 2;
}