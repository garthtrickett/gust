unsafe func make_zero() *int { return 0 as *int; }
func relay_zero() *int {
    unsafe { mut ptr := make_zero(); mut first := ptr; mut second := first; return second; }
}
func main() int { return 0; }
