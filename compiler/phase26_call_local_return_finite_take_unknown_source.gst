unsafe func make_nonzero() *int { return 1 as *int; }
unsafe func make_unknown() *int { return make_nonzero(); }
func relay() *int {
    unsafe { mut ptr := make_unknown(); return take (take (take ptr)); }
}
func main() int { return 0; }
