unsafe func make_unknown(v: *int) *int { return v; }
func relay_mayzero() *int {
    unsafe { mut ptr := make_unknown(1 as *int); return take ptr; }
}
func main() int { return 0; }
