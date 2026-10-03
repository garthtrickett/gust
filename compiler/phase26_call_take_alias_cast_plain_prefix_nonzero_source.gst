unsafe func make_nonzero() *int { return 1 as *int; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_nonzero(); mut plain := ptr; mut alias := take plain; accept_raw(alias as *int); }
    return 0;
}
