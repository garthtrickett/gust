unsafe func make_zero() *int { return empty[*int]; }
func accept_int(n: int) {}
func main() int { unsafe { accept_int(make_zero() as *int); } return 0; }
