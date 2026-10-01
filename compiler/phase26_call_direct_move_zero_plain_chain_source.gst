func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut first := ptr; mut second := first; accept_raw(move second); }
    return 0;
}
unsafe func make_zero() *int { return empty[*int]; }
