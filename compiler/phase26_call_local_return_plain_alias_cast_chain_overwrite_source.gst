unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay_nonzero() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr; alias = 1 as *int; return (alias as *int) as *int; }
}
func main() int { return 0; }
