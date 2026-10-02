unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_mayzero(); accept_raw(take (ptr as *int)); }
    return 0;
}
