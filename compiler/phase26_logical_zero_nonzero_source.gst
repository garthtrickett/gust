func accept_raw(ptr: *int) {}
func main() int {
    unsafe { accept_raw((false || true) as *int); }
    return 0;
}
