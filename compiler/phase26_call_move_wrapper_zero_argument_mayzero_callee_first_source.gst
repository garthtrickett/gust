unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { accept_raw(move make_mayzero()); }
    return 0;
}
