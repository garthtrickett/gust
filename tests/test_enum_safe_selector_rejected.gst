type MyEnum enum { VariantA { val: int } }
func main() {
    mut e: MyEnum;
    mut x := e.VariantA.val; // Trigger DirectEnumAccessForbidden
}