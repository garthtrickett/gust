unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_mayzero(); mut first := ptr; mut second := first; mut third := second; accept_raw(third); }
    return 0;
}
