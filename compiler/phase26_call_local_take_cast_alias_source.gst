unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut alias := ptr; accept_raw(take (alias as *int)); }
    return 0;
}
