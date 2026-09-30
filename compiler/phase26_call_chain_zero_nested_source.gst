unsafe func make_zero() *int { return empty[*int]; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_zero(); mut first := ptr; mut second := first; mut third := second; if true { accept_raw(third); } }
    return 0;
}
