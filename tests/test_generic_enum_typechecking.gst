type MyResult[T, ctx] enum {
    Ok { val: T },
    Err { val: int }
}
func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();
    mut res: MyResult[int, ctx];
    unsafe {
        res.tag = 0;
        res.Ok.val = 42;
    }
    os.LogInt(res.Ok.val);
}
