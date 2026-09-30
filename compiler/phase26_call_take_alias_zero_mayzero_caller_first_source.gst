func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_mayzero(); mut alias := take ptr; accept_raw(alias); }
    return 0;
}
unsafe func make_mayzero() *int { return (256 as byte) as *int; }
