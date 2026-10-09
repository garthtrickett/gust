unsafe func make_mayzero() *int { return (256 as byte) as *int; }
unsafe func relay() *int {
    unsafe { mut ptr := make_mayzero(); return take (take (take (move (take ptr)))); }
}
func main() int { return 0; }
