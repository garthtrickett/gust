func accept_raw(ptr: *int) {}
func main() int {
    unsafe { accept_raw(1 as *int); }
    return 0;
}
