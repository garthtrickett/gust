unsafe func make_nonzero() *int { return 1 as *int; }
func relay() *int {
    unsafe { mut ptr := make_nonzero(); mut alias := ptr as *int; return take (take alias); }
}
func main() int { return 0; }
