func relay() *int { unsafe { return (move make_mayzero()) as *int; } }
unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func main() int { return 0; }
