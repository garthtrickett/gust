unsafe func make_zero() *int { return empty[*int]; }
unsafe func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut taken := take ptr; mut suffix := taken; accept_raw(suffix); }
    return 0;
}
