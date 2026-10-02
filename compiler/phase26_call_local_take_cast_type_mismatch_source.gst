unsafe func make_zero() *int { return empty[*int]; }
func accept_int(value: int) {}
func main() int {
    unsafe { mut ptr := make_zero(); accept_int(take (ptr as *int)); }
    return 0;
}
