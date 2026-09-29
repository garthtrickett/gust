type Holder struct { ptr: *int }
func accept_raw(ptr: *int) {}
func main() int {
    mut holder: Holder;
    mut alias: Holder;
    unsafe { holder.ptr = (0 + 0) as *int; alias = take holder; accept_raw(alias.ptr); }
    return 0;
}
