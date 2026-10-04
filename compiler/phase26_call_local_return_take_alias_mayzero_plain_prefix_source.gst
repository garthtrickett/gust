unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay_mayzero() *int {
    unsafe { mut ptr := make_mayzero(); mut first := ptr; mut alias := take first; return alias; }
}
func main() int { return 0; }
