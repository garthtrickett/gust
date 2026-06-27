func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut nums: std.Vector[int, ctx] := std.VectorNew(ctx);
    nums.Push(10);
    nums.Push(20);
    nums.Push(30);

    os.LogInt(nums[1]);

    nums.Set(1, 99);
    os.LogInt(nums[1]);

    mut idx := 0;
    nums.Set(idx, 44);
    os.LogInt(nums[0]);
}