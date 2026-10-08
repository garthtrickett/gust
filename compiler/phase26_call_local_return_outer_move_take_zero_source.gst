unsafe func make_zero() *int { return 0 as *int; }
func safe_return() *int {
    unsafe { mut ptr := make_zero(); return move (take ptr); }
}
func main() int { return 0; }
