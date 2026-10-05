unsafe func make_nonzero() *int { return 1 as *int; }
func relay_mayzero() *int {
    unsafe { mut ptr := make_nonzero(); return take ptr; }
}
func main() int { return 0; }
