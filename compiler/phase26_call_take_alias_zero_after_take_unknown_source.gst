unsafe func make_unknown(value: int) *int { return value as *int; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_unknown(0); mut taken := take ptr; mut suffix := taken; accept_raw(suffix); }
    return 0;
}
