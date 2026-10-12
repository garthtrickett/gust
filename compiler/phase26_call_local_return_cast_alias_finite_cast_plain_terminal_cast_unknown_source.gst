unsafe func make_nonzero() *int { return 1 as *int; }
unsafe func make_unknown() *int { return make_nonzero(); }
func relay() *int {
    unsafe { mut ptr := make_unknown(); mut alias := ptr as *int; mut second := alias as *int; mut third := second as *int; mut fourth := third as *int; mut terminal := fourth; mut later := terminal; return later as *int; }
}
func main() int { return 0; }
