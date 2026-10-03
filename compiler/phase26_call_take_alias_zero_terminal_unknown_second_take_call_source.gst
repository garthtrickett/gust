unsafe func make_nonzero() *int { return 1 as *int; }
unsafe func make_ptr() *int { return make_nonzero(); }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_ptr(); mut first := take ptr; mut second := take first; accept_raw(take second); }
    return 0;
}
