unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay_mayzero() *int {
    unsafe { mut ptr := make_mayzero(); mut first := ptr; mut second := first; return second; }
}
func main() int { return 0; }
