unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut alias := take ptr; accept_raw((alias as *int) as *int); }
    return 0;
}
