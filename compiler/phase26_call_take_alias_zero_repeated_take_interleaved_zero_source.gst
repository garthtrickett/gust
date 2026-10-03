unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut first := take ptr; mut plain := first; mut second := take plain; mut tail := second; mut third := take tail; accept_raw((third as *int) as *int); }
    return 0;
}
