unsafe func make_zero() *int { return empty[*int]; }
func accept_int(value: int) {}
func main() int { unsafe { accept_int(move ((take make_zero() as *int) as *int)); } return 0; }
