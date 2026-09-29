func accept_raw(ptr: *int) {}
func forward(flag: bool) {
    unsafe { accept_raw((flag && false) as *int); }
}
func main() int { return 0; }
