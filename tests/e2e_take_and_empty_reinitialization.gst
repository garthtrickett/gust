type Resource[T, ctx] struct {
    val: T,
    active: int
}

func swap_resources(ctx: &Arena, a: *Resource[str, ctx], b: *Resource[str, ctx]) {
    mut temp: Resource[str, ctx] := empty[Resource[str, ctx]];
    unsafe {
        temp = take *a;
        *a = take *b;
        *b = move temp;
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut r1: Resource[str, ctx];
    r1.val = "Hello";
    r1.active = 1;

    mut r2: Resource[str, ctx];
    r2.val = "World";
    r2.active = 2;

    swap_resources(ctx, &r1, &r2);

    os.LogStr(r1.val);
    os.LogInt(r1.active);
    os.LogStr(r2.val);
    os.LogInt(r2.active);
}