func accept_raw(ptr: *int) {}
unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func main() { unsafe { accept_raw(make_mayzero()); } }
