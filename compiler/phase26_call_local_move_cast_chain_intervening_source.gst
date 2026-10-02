unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut other := 1; accept_raw(move ((ptr as *int) as *int)); }
    return 0;
}
