type MyLinear struct {
    ptr: *int
}
func main() {
    mut p: MyLinear;
    mut p2 := move p;
    mut err := p.ptr;
}