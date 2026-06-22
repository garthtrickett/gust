type Wrapper[T] struct {
    val: T
}
func main() {
    mut w1: Wrapper[int];
    w1.val = 42;
    mut w2 := move w1;
    os.LogInt(w1.val);
}