unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_mayzero(); mut taken := take ptr; mut suffix := taken; accept_raw(suffix); }
    return 0;
}
