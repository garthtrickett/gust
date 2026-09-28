type Inner struct { ptr: *int }
type Outer struct { inner: Inner }
func accept_raw(ptr: *int) {}
func main() int {
    mut outer: Outer;
    unsafe { outer.inner.ptr = 1 as *int; if 1 { outer.inner.ptr = (0 + 0) as *int; } accept_raw(outer.inner.ptr); }
    return 0;
}
