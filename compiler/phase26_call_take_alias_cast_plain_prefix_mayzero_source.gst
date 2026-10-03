func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_mayzero(); mut plain := ptr; mut alias := take plain; accept_raw((alias as *int) as *int); }
    return 0;
}
unsafe func make_mayzero() *int { return (256 as byte) as *int; }
