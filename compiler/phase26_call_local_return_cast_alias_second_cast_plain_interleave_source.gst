unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr as *int; mut middle := alias; mut second := middle as *int; return second; }
}
func main() int { return 0; }
