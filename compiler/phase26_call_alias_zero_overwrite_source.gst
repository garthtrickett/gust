unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut alias := ptr; alias = 1 as *int; accept_raw(alias); }
    return 0;
}
