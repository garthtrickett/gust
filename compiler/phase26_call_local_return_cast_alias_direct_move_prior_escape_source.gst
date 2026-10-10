func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr as *int; return move alias; }
}
unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func main() int { return 0; }
