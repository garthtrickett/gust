unsafe func make_mayzero() *int { return 0 as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr as *int; mut second := alias as *int; mut third := second as *int; mut fourth := third as *int; return move fourth; }
}
func main() int { return 0; }
