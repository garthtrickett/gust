unsafe func make_nonzero() *int { return 1 as *int; }
unsafe func make_unknown() *int { return make_nonzero(); }
func relay() *int {
    unsafe { mut ptr := make_unknown(); mut alias := ptr as *int; return (take alias) as *int; }
}
func main() int { return 0; }
