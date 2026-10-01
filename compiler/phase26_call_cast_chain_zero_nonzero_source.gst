unsafe func make_nonzero() *int { return 1 as *int; }
func accept_raw(ptr: *int) {}
func main() int { unsafe { accept_raw((make_nonzero() as *int) as *int); } return 0; }
