unsafe func make_nonzero() *int { return 1 as *int; }
unsafe func make_unknown() *int { return make_nonzero(); }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_unknown(); mut alias := ptr; mut second := alias; accept_raw((second as *int) as *int); }
    return 0;
}
