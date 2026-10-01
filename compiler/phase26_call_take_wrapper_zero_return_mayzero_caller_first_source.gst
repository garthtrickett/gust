func relay_mayzero() *int {
    unsafe { return take make_mayzero(); }
}
unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func main() int { return 0; }
