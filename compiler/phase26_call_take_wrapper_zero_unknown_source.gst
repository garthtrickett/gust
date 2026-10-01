unsafe func pass_raw(ptr: *int) *int { return ptr; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { accept_raw(take pass_raw(1 as *int)); }
    return 0;
}
