unsafe func make_zero() *int { return empty[*int]; }
func relay() *int { unsafe { return (make_zero() as *int) as *int; } }
func main() int { return 0; }
