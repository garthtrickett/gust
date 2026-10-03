unsafe func make_ptr() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_ptr(); mut plain := ptr; mut taken := take plain; accept_raw(take taken); }
    return 0;
}
