type MyLinear struct {
    ptr: *int
}
func main() {
    mut p: MyLinear;
    mut val := 10;
    unsafe {
        p.ptr = &val;
    }
    mut taken := take p;
}
