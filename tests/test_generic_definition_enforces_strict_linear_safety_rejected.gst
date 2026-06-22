type Holder[T] struct {
    val: T
}
func process(h: Holder[T]) {
    mut h2 := move h;
    mut y := h.val;
}
func main() {}