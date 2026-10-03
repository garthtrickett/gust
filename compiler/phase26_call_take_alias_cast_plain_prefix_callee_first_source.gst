unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut plain := ptr; mut alias := take plain; accept_raw((alias as *int) as *int); }
    return 0;
}
