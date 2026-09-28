type Holder struct { ptr: *int }
func accept_raw(ptr: *int) {}
func main() int {
    mut holder: Holder;
    mut other: Holder;
    unsafe { holder.ptr = 0 as *int; holder = other; accept_raw(holder.ptr); }
    return 0;
}
