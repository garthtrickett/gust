unsafe func make_nonzero() *int { return 1 as *int; }
unsafe func make_unknown() *int { return make_nonzero(); }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_unknown(); mut first := ptr; mut second := first; mut third := second; accept_raw(third); }
    return 0;
}
