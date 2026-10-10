unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr as *int; mut second := alias as *int; mut middle := second; mut third := middle as *int; mut fourth := third as *int; return fourth; }
}
func main() int { return 0; }
