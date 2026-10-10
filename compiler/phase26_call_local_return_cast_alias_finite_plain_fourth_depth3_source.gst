unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := (((ptr as *int) as *int) as *int); mut second := alias; mut third := second; mut fourth := third; return fourth; }
}
func main() int { return 0; }
