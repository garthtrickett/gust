unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func accept_raw(ptr: *int) {}
func main() int { unsafe { accept_raw(make_mayzero() as *int); } return 0; }
