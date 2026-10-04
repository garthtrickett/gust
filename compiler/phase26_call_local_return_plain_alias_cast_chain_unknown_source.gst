unsafe func pass_raw(ptr: *int) *int { return ptr; }
func relay_unknown(ptr: *int) *int {
    unsafe { mut local := pass_raw(ptr); mut alias := local; return (alias as *int) as *int; }
}
func main() int { return 0; }
