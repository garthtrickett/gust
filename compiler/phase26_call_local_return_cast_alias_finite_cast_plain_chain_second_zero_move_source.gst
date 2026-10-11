unsafe func make_mayzero() *int { return 0 as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr as *int; mut second := alias as *int; mut third := second as *int; mut fourth := third as *int; mut terminal := fourth; mut later := terminal; return move later; }
}
func main() int { return 0; }
