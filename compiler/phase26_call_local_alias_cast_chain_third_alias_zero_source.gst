unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut alias := ptr; mut second := alias; mut third := second; accept_raw((third as *int) as *int); }
    return 0;
}
