unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func broken() int { return "wrong"; }
func main() int {
    unsafe { mut ptr := make_zero(); accept_raw(ptr); }
    return 0;
}
