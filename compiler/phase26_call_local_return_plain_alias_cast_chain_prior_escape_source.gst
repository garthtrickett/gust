func relay_mayzero() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr; return (alias as *int) as *int; }
}
unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func main() int { return 0; }
