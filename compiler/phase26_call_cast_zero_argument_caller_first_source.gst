func main() int { unsafe { accept_raw(make_zero() as *int); } return 0; }
func accept_raw(ptr: *int) {}
unsafe func make_zero() *int { return empty[*int]; }
