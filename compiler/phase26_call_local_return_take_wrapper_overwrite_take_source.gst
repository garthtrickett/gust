unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay_mayzero() *int {
    unsafe { mut ptr := make_mayzero(); ptr = 1 as *int; return take ptr; }
}
func main() int { return 0; }
