func accept_raw(ptr: *int) {}
func route(n: int) {
    unsafe { accept_raw(((n as byte) as int) as *int); }
}
func main() int { return 0; }
