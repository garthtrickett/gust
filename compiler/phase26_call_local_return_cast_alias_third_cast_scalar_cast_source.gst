unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr as *int; mut second := alias as *int; mut third := (second as int) as *int; return third; }
}
func main() int { return 0; }
