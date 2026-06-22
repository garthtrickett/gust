type MyLinear struct {
    ptr: *int
}
type NestedEnum enum {
    VariantA { val: MyLinear },
    VariantB
}
type OuterPod struct {
    id: int,
    payload: NestedEnum
}
func main() {
    mut o: OuterPod;
    o.id = 42;
    mut o2 := move o;
    os.LogInt(o.id);
}