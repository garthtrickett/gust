func accept_raw(ptr: *int) {}
func forward(value: int) {
    unsafe { accept_raw((value < 0) as *int); }
}
func main() int { return 0; }
