unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func broken() int { return "wrong"; }
func main() int { unsafe { accept_raw(move take move make_zero()); } return 0; }
