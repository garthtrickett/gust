type Wrapper[T] struct {
    val: T
}
func main() {
    mut w1: Wrapper[*int];
    mut w2 := move w1;
    mut err := w1.val;
}