type MyEnum enum {
    VariantA { val: int },
    VariantB { x: int, y: int }
}
func process(e: MyEnum) int {
    match e {
        VariantA { val } => {
            return *val;
        }
        VariantB { x, y } => {
            return *x + *y;
        }
    }
}
func main() {}
