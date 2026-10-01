unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut unrelated := 1; accept_raw(move ptr); }
    return 0;
}
