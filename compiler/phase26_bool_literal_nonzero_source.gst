func accept_raw(ptr: *int) {}
func main() int {
    unsafe { accept_raw(true as *int); }
    return 0;
}
