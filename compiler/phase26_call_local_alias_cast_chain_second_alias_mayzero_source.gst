unsafe func make_mayzero() *int { return (256 as byte) as *int; }
func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := make_mayzero(); mut alias := ptr; mut second := alias; accept_raw((second as *int) as *int); }
    return 0;
}
