type MyEnum enum { VariantB }
func main() {
    mut e: MyEnum;
    e.tag = 1; // Trigger EnumMutationForbidden
}