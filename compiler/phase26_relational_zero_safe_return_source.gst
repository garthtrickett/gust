func safe_zero() *int { unsafe { return (0 > 0) as *int; } }
func main() int { return 0; }
