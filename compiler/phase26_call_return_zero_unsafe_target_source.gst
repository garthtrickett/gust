unsafe func make_zero() *int { return empty[*int]; }
unsafe func accept_raw(ptr: *int) {}
func main() int {
    unsafe { accept_raw(make_zero()); }
    return 0;
}
