unsafe func make_zero() *int { return empty[*int]; }
func accept_int(x: int) {}
func main() int {
    unsafe { mut ptr := make_zero(); accept_int(move ((ptr as *int) as *int)); }
    return 0;
}
