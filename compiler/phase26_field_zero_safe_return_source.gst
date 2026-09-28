type Holder struct { ptr: *int }
func give_raw() *int {
    mut holder: Holder;
    unsafe { holder.ptr = (0 + 0) as *int; }
    return holder.ptr;
}
func main() int { return 0; }
