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
            mut index := empty[Index[LargePayload, ctx]];
            unsafe {
                index = e.VariantA.val;
            }
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
    mut p_ref_enum_indirection := ctx.get_ref(p);
    p_ref_enum_indirection.x = 10;
    p_ref_enum_indirection.y = 20;
    p_ref_enum_indirection.z = 30;

    mut e: MyEnum[ctx];
    unsafe {
        e.tag = 0;
        e.VariantA.val = p;
    }

    mut res := process(e, ctx);
    os.LogInt(res);
}
