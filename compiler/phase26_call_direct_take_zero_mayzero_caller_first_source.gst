func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_mayzero(); accept_raw(take ptr); }
    return 0;
}
unsafe func make_mayzero() *int { return (256 as byte) as *int; }
