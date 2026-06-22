type MyLinear struct {
    ptr: *int
}
type LinearEnum enum {
    VariantA { val: MyLinear },
    VariantB
}
func main() {
    mut e: LinearEnum;
    e.tag = 0;
    mut e2 := move e;
    os.LogInt(e.tag);
}