unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); os.LogInt(1); return take (take (take (move ptr))); }
}
func main() int { return 0; }
