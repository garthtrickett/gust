type MyLinear struct {
    ptr: *int
}
func main() {
    mut p1: MyLinear;
    mut p2 := move p1;
}