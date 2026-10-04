func main() int {
    unsafe { mut ptr := make_ptr(); mut first := take ptr; mut second := take first; accept_raw(take (take (take (second)))); }
    return 0;
}
func accept_raw(ptr: *int) {}
unsafe func make_ptr() *int { return empty[*int]; }
