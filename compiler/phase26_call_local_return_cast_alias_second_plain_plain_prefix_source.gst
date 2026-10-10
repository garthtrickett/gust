unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut first := ptr; mut alias := first as *int; mut second := alias; return second; }
}
func main() int { return 0; }
