unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr; os.LogInt(1); return ((move (take (take alias))) as *int); }
}
func main() int { return 0; }
