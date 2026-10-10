unsafe func make_mayzero() *int { return 1 as *int; }
func relay() *int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr as *int; mut second := alias as *int; return second; }
}
func main() int { return 0; }
