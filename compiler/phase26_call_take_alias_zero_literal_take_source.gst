func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := empty[*int]; mut alias := take ptr; accept_raw(alias); }
    return 0;
}
