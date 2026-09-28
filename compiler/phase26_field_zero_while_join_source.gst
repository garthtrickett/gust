type Holder struct { ptr: *int }
func accept_raw(ptr: *int) {}
func main() int {
    mut flag := 1;
    mut holder: Holder;
    unsafe { holder.ptr = 1 as *int; while flag { holder.ptr = 0 as *int; flag = 0; } accept_raw(holder.ptr); }
    return 0;
}
