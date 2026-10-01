unsafe func make_zero() *int { return empty[*int]; }
func main() int { return 0; }
func relay() *int { unsafe { return take (make_zero() as *int); } }
