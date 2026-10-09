unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); return take (move (take (take ((ptr as *int))))); }
}
func main() int { return 0; }
