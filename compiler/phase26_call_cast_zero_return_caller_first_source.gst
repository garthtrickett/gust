func relay_zero() *int { unsafe { return make_zero() as *int; } }
func main() int { return 0; }
unsafe func make_zero() *int { return empty[*int]; }
