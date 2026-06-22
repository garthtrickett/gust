type LargePayload struct {
    x: int,
    y: int,
    z: int
}

type MyEnum[ctx] enum {
    VariantA { val: Index[LargePayload, ctx] },
    VariantB
}

func process(e: MyEnum[ctx], ctx: &Arena) int {
    match e {
        VariantA => {
            mut index := e.VariantA.val;
            return ctx[index].x + ctx[index].y + ctx[index].z;
        }
        VariantB => {
            return 0;
        }
    }
}

func main() {
    mut ctx := os.Arena.New();
    defer ctx.Free();

    mut p: Index[LargePayload, ctx] := os.ArenaAlloc(ctx);
    ctx[p].x = 10;
    ctx[p].y = 20;
    ctx[p].z = 30;

    mut e: MyEnum[ctx];
    e.tag = 0;
    e.VariantA.val = p;

    mut res := process(e, ctx);
    os.LogInt(res);
}
