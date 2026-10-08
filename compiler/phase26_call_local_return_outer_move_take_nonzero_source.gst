unsafe func make_nonzero() *int { return 1 as *int; }
func safe_return() *int {
    unsafe { mut ptr := make_nonzero(); return move (take ptr); }
}
func main() int { return 0; }
