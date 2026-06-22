type Element[T] struct {
    val: T,
    id: int
}

func main() {
    mut el1: Element[int];
    el1.val = 42;
    el1.id = 101;

    // Since T is int, Element[int] propagates to a copyable POD!
    mut el2 := move el1; 

    // Verify both the moved-from and the moved-to structures remain fully readable and optimized in C
    os.LogInt(el1.id);
    os.LogInt(el1.val);
    os.LogInt(el2.id);
    os.LogInt(el2.val);
}