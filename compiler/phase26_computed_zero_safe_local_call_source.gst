func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut n := 0; accept_raw(n as *int); }
    return 0;
}
