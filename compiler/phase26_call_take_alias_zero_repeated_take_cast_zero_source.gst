unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut first := take ptr; mut second := take first; accept_raw((second as *int) as *int); }
    return 0;
}
