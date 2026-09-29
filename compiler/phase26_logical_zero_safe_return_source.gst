func safe_zero() *int { unsafe { return (true && false) as *int; } }
func main() int { return 0; }
