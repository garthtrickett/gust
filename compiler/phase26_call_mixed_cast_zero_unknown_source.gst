unsafe func pass_raw(ptr: *int) *int { return ptr; }
unsafe func make_unknown() *int { return pass_raw(1 as *int); }
func accept_raw(ptr: *int) {}
func main() int { unsafe { accept_raw((take make_unknown()) as *int); } return 0; }
