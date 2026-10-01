unsafe func make_zero() *int { return empty[*int]; }
unsafe func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); accept_raw(move ptr); }
    return 0;
}
