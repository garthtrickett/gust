unsafe func make_zero() *int { return 0 as *int; }
func relay() *int {
    unsafe { mut ptr := make_zero(); mut alias := ptr; return ((move (take alias)) as *int); }
}
func main() int { return 0; }
