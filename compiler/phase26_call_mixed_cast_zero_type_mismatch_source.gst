unsafe func make_zero() *int { return empty[*int]; }
func accept_int(value: int) {}
func main() int { unsafe { accept_int((take make_zero()) as *int); } return 0; }
