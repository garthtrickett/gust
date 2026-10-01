unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: int) {}
func main() int {
    unsafe { accept_raw(take make_zero()); }
    return 0;
}
