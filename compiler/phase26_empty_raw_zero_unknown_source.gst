func accept_raw(ptr: *int) {}
func forward(ptr: *int) { unsafe { accept_raw(ptr); } }
func main() int { return 0; }
