func main() int { unsafe { accept_raw(move ((take make_zero() as *int) as *int)); } return 0; }
func accept_raw(ptr: *int) {}
unsafe func make_zero() *int { return empty[*int]; }
