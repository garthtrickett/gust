unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr; mut consumed := move alias; return ((move (take (take alias))) as *int); }
}
func main() int { return 0; }
