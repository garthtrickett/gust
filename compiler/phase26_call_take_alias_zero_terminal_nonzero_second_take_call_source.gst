unsafe func make_ptr() *int { return 1 as *int; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_ptr(); mut first := take ptr; mut second := take first; accept_raw(take second); }
    return 0;
}
