unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut taken := take ptr; mut suffix := taken; mut second := take suffix; accept_raw(second); }
    return 0;
}
