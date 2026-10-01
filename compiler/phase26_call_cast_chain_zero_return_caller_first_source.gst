func relay() *int { unsafe { return (make_zero() as *int) as *int; } }
unsafe func make_zero() *int { return empty[*int]; }
func main() int { return 0; }
