unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr; return take (move (take (take (((alias as int) as *int))))); }
}
func main() int { return 0; }
