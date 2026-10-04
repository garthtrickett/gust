unsafe func pass_raw(ptr: *int) *int { return ptr; }
func relay_unknown(ptr: *int) *int {
    unsafe { mut local := pass_raw(ptr); return local; }
}
func main() int { return 0; }
