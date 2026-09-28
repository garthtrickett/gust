type Inner struct { ptr: *int }
type Outer struct { inner: Inner }
func main() int {
    mut outer: Outer;
    unsafe { outer.inner.ptr = 1 as *int; }
    os.LogInt(42);
    return 0;
}
