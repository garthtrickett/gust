type Inner struct { ptr: *int }
type Outer struct { inner: Inner }
func return_raw() *int {
    mut outer: Outer;
    unsafe { outer.inner.ptr = (0 + 0) as *int; }
    return outer.inner.ptr;
}
func main() int { return 0; }
