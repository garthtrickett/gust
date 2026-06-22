type Large struct {
    x: int,
    y: int,
    z: int
}

type MyEnum enum {
    VariantA { val: Large },
    VariantB
}

func main() {
    mut e: MyEnum;
    e.tag = 0;
    e.VariantA.val.x = 42;
}