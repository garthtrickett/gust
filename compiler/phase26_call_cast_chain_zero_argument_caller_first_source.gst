func main() int { unsafe { accept_raw((make_zero() as *int) as *int); } return 0; }
unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
