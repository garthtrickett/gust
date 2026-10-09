unsafe func make_nonzero() *int { return 1 as *int; }
func relay() *int {
    unsafe { mut ptr := make_nonzero(); return take (move (take (take (ptr)))); }
}
func main() int { return 0; }
