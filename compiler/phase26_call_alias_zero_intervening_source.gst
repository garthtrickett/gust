unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut alias := ptr; mut unrelated := 1; accept_raw(alias); }
    return 0;
}
