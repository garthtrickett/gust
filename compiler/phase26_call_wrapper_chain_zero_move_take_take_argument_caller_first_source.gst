func accept_raw(ptr: *int) {}
func main() int {
    unsafe { accept_raw(move take take make_zero()); }
    return 0;
}
unsafe func make_zero() *int { return empty[*int]; }
