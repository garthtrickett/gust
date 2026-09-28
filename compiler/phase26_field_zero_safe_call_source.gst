type Holder struct { ptr: *int }
func accept_raw(ptr: *int) {}
func main() int {
    mut holder: Holder;
    unsafe { holder.ptr = (0 + 0) as *int; accept_raw(holder.ptr); }
    return 0;
}
