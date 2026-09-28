type Holder struct { ptr: *int }
func accept_raw(ptr: *int) {}
func main() int {
    mut flag := 1;
    mut holder: Holder;
    unsafe { if flag { holder.ptr = 0 as *int; } else { holder.ptr = 1 as *int; } accept_raw(holder.ptr); }
    return 0;
}
