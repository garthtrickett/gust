type MyEnum enum { VariantA { val: int } }
func main() {
    mut e: MyEnum;
    unsafe {
        e.tag = 0;
        mut x := e.VariantA.val;
    }
}