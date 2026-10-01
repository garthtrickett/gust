func accept_raw(ptr: *int) {}
func main() int {
    unsafe { mut ptr := empty[*int]; accept_raw(move ptr); }
    return 0;
}
