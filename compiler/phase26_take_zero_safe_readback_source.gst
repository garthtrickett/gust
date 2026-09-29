func accept_raw(ptr: *int) {}
func run() {
    mut p: *int;
    mut q: *int;
    unsafe { p = (0 + 0) as *int; q = take p; accept_raw(q); }
}
func main() int { return 0; }
