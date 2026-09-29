func accept_raw(ptr: *int) {}
func run() {
    mut p: *int;
    unsafe { p = (0 + 0) as *int; accept_raw(take p); }
}
func main() int { return 0; }
