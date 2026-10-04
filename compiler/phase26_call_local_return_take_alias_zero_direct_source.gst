unsafe func make_zero() *int { return 0 as *int; }
func relay_zero() *int {
    unsafe { mut ptr := make_zero(); mut alias := take ptr; return alias; }
}
func main() int { return 0; }
