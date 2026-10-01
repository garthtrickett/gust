unsafe func make_zero() *int { return empty[*int]; }
unsafe func accept_raw(ptr: *int) {}
func main() int { unsafe { accept_raw(move (make_zero() as *int)); } return 0; }
