func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut x := 1; accept_raw(ptr as *int); }
    return 0;
}
unsafe func make_zero() *int { return empty[*int]; }
