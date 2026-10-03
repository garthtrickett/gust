unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut first := ptr; mut second := first; mut alias := take second; accept_raw(alias as *int); }
    return 0;
}
