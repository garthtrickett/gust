unsafe func make_unknown(ptr: *int) *int { return ptr; }
func accept_raw(ptr: *int) {}
func main() int { unsafe { accept_raw(move take move make_unknown(1 as *int)); } return 0; }
