func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := empty[*int]; accept_raw(take ptr); }
    return 0;
}
