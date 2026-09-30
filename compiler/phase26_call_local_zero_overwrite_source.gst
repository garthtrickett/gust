unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); ptr = 1 as *int; accept_raw(ptr); }
    return 0;
}
