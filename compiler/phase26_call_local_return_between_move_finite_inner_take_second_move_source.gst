unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); return take (move (move (take (take (ptr))))); }
}
func main() int { return 0; }
