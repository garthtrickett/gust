unsafe func make_ptr() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_ptr(); mut first := take ptr; mut second := take first; accept_raw(move (take ((take (second as *int)) as *int))); }
    return 0;
}
