func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut alias := take ptr; mut marker := 1; accept_raw(alias as *int); }
    return 0;
}
unsafe func make_zero() *int { return empty[*int]; }
