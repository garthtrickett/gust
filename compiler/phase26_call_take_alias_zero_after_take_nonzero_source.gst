unsafe func make_nonzero() *int { return 1 as *int; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_nonzero(); mut taken := take ptr; mut suffix := taken; accept_raw(suffix); }
    return 0;
}
