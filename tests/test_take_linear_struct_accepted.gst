type MyLinear struct {
    ptr: *int
}
func main() {
    mut p: MyLinear;
    unsafe {
        p.ptr = &10;
    }
    mut taken := take p;
}