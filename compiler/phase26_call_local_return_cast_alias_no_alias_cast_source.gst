unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := make_mayzero() as *int; return alias; }
}
func main() int { return 0; }
