unsafe func make_zero() *int { return 0 as *int; }
func relay() *int {
    unsafe { mut ptr := make_zero(); return take (move (take ptr)); }
}
func main() int { return 0; }
