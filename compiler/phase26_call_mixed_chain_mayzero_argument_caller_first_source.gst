func main() int { unsafe { accept_raw(move ((take make_mayzero() as *int) as *int)); } return 0; }
func accept_raw(ptr: *int) {}
unsafe func make_mayzero() *int { return (256 as byte) as *int; }
