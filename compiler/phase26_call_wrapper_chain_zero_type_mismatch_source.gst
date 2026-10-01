unsafe func make_zero() *int { return empty[*int]; }
func accept_int(n: int) {}
func main() int { unsafe { accept_int(move take move make_zero()); } return 0; }
