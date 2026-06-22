type MyEnum enum {
    VariantA { val: int },
    VariantB
}
func process(e: MyEnum) int {
    match e {
        VariantA { nonexistent } => {
            return 1;
        }
        VariantB => {
            return 0;
        }
    }
}
func main() {}