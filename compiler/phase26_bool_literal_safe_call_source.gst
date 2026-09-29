func accept_raw(ptr: *int) {}
func main() int {
    unsafe { accept_raw(false as *int); }
    return 0;
}
