unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr; return take (take (take (take (move ((alias as *int) as *int))))); }
}
func main() int { return 0; }
