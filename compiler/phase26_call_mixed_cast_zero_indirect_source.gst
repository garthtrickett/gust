unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int { unsafe { mut f := make_zero; accept_raw(move (f() as *int)); } return 0; }
