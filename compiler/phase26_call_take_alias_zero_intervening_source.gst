unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut unrelated := 1; mut alias := take ptr; accept_raw(alias); }
    return 0;
}
