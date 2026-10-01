unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int { unsafe { accept_raw((1 as int) as *int); } return 0; }
