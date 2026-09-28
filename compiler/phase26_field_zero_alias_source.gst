type Holder struct { ptr: *int }
func accept_raw(ptr: *int) {}
func main() int {
    mut holder: Holder;
    unsafe { holder.ptr = 0 as *int; mut alias := holder; accept_raw(alias.ptr); }
    return 0;
}
