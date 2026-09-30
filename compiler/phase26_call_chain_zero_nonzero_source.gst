unsafe func make_nonzero() *int { return 1 as *int; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_nonzero(); mut first := ptr; mut second := first; mut third := second; accept_raw(third); }
    return 0;
}
