func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut first := ptr; mut second := first; mut third := second; mut alias := take third; accept_raw(alias as *int); }
    return 0;
}
unsafe func make_zero() *int { return empty[*int]; }
