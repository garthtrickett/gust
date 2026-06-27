type MyEnum enum {
    VariantA { val: int },
    VariantB { x: int, y: int }
}
func process(e: MyEnum) int {
    match e {
        VariantA { val } => {
            unsafe {
                return *val;
            }
        }
        VariantB { x, y } => {
            unsafe {
                return *x + *y;
            }
        }
    }
}
func main() {}
