unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *byte) {}
func main() int { unsafe { accept_raw(make_zero() as *byte); } return 0; }
