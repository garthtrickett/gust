unsafe func accept_raw(ptr: *int) {}
func main() int {
    unsafe { accept_raw(empty[*int]); }
    return 0;
}
