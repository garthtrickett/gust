func accept_raw(ptr: *int) {}
unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func main() int {
    unsafe { mut ptr := make_mayzero(); accept_raw(move ((ptr as *int) as *int)); }
    return 0;
}
