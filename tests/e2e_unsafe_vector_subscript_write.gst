func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    os.SetThreadScratch(ctx);

    mut nums: std.Vector[int, ctx] := std.VectorNew(ctx);
    nums.Push(1);

    // Step 4.5C: explicit unsafe blocks may still perform direct vector slot writes.
    unsafe {
        nums[0] = 2;
    }

    if nums[0] != 2 {
        os.Exit(1);
    }
}