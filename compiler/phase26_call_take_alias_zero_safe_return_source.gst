unsafe func make_zero() *int { return empty[*int]; }
func safe_out() *int {
    unsafe { mut ptr := make_zero(); mut alias := take ptr; return alias; }
}
func main() int { return 0; }
