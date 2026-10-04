unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay_mayzero() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := take ptr; return alias; }
}
func main() int { return 0; }
