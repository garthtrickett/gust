func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_mayzero(); mut first := ptr; mut second := first; mut alias := take second; accept_raw((alias as *int) as *int); }
    return 0;
}
unsafe func make_mayzero() *int { return (256 as byte) as *int; }
