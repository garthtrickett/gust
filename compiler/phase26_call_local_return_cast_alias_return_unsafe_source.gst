unsafe func make_mayzero() *int { return (256 as byte) as *int; }
unsafe func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr as *int; return alias as *int; }
}
func main() int { return 0; }
