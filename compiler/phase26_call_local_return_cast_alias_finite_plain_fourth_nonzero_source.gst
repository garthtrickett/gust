unsafe func make_nonzero() *int { return 1 as *int; }
func relay() *int {
    unsafe { mut ptr := make_nonzero(); mut alias := ptr as *int; mut second := alias; mut third := second; mut fourth := third; return fourth; }
}
func main() int { return 0; }
