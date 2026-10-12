unsafe func make_zero() *int { return 0 as *int; }
func relay() *int {
    unsafe { mut ptr := make_zero(); mut alias := ptr as *int; mut second := alias as *int; mut third := second as *int; mut fourth := third as *int; mut terminal := fourth; mut later := terminal; return ((later as *int) as *int) as *int; }
}
func main() int { return 0; }
