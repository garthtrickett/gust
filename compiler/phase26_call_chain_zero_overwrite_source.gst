unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut first := ptr; mut second := first; mut third := second; third = 1 as *int; accept_raw(third); }
    return 0;
}
