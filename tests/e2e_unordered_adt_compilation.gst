type AOuter enum {
    VariantA { val: ZInner }
}

type ZInner struct {
    x: int
}

type ZOuter enum {
    VariantA { val: AInner }
}

type AInner struct {
    x: int
}

func main() {
    mut o1: AOuter;
    unsafe {
        o1.tag = 0; // VariantA
        o1.VariantA.val.x = 42;
        os.LogInt(o1.VariantA.val.x);
    }

    mut o2: ZOuter;
    unsafe {
        o2.tag = 0; // VariantA
        o2.VariantA.val.x = 84;
        os.LogInt(o2.VariantA.val.x);
    }
}
