unsafe func make_nonzero() *int { return 1 as *int; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_nonzero(); accept_raw((ptr as *int) as *int); }
    return 0;
}
