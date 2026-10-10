unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut prefix := ptr; mut alias := prefix as *int; mut second := alias as *int; mut third := second as *int; mut fourth := third as *int; return fourth; }
}
func main() int { return 0; }
