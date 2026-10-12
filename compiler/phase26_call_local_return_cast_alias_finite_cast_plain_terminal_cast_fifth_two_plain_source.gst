unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr as *int; mut second := alias as *int; mut third := second as *int; mut fourth := third as *int; mut fifth := fourth as *int; mut terminal := fifth; mut later := terminal; return later as *int; }
}
func main() int { return 0; }
