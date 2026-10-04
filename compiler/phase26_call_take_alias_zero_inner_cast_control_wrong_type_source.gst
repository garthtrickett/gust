unsafe func make_ptr() *int { return empty[*int]; }
func accept_int(value: int) {}
func main() int {
    unsafe { mut ptr := make_ptr(); mut first := take ptr; mut second := take first; accept_int(take (second as *int)); }
    return 0;
}
